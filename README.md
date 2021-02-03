# Demo of https://github.com/protocolbuffers/protobuf/issues/1491

## Using this repo

### To run the examples in native Python

    pip install protobuf
    cd broken
    python main.py

Expected:

    Foo proto successfully serialized to: {
        "bar": {
            "greeting": "hello world"
        }
    }


Actual behavior:

    Traceback (most recent call last):
    File "main.py", line 3, in <module>
        from pb_generated.foo_pb2 import Foo
    File "/home/fsufitch/private/protobuf-issue-1491/broken/pb_generated/foo_pb2.py", line 14, in <module>
        import bar_pb2 as bar__pb2
    ModuleNotFoundError: No module named 'bar_pb2'

All workarounds can be run the same way.

### Rebuild the _pb2 files and run the examples in Docker

    ./build_protos.sh
    ./run_examples.sh

## What's the problem?

The Protobuf compiler plugin for Python was designed for Python 2's import mechanics. Different behavior under
Python 3 is causing trouble. The key problematic generated code is of the shape:

    import foo as foo_2

In Python 2, this had two interpretations:

1. If the current file has a sibling called `foo.py`, then load it and expose its namespace as the variable `foo_2`. (Relative import)
2. Iterate through the paths in `sys.path` and look for a fitting import path called `foo`. If it's found, load it and expose its namespace as the variable `foo_2`. (Absolute import)

In Python 3, the same code does **not** execute relative imports anymore. It does **not** check siblings, then fall back on `sys.path`; instead, it directly refers to 
`sys.path`. Relative imports need to be explicit, using dot notation (e.g. `import .foo as foo_2` or `from . import foo as foo_2`), and don't fall back on the system path.

This is a problem for Protobuf because a very simple source structure like this:

    - main.py         # contains: from pb_sources import foo_pb2
    - pb_sources/
      |-- foo.proto   # contains: import "bar.proto"
      |-- bar.proto
    - pb_generated/
      |-- foo_pb2.py
      |-- bar_pb2.py

Which is compiled with a command like this:

    protoc -I pb_sources/ --python_out pb_generated/ pb_sources/foo.proto pb_soutces/bar.proto

Results in `foo_pb2.py` containing this line:

    import bar_pb2 as bar__pb2

This parallels the *exact* description of the difference in import mechanics between Python 2 and 3. The import fails because the code appears to be designed assuming that import
could be relative, and while that was a true assumption in Python 2, *it is no longer true in Python 3*. 

**TLDR: `protoc --python_out=OUTPUT_DIR` produces code that is broken at runtime unless `OUTPUT_DIR` is in `sys.path`.**

## Should protoc just generate relative imports to fix this?

**No!** The proposed fix in the OP is not workable. It would work fine when the `.proto` files are siblings, but would otherwise
create a giant mess -- especially when `protoc` has `-I` specified multiple times.

## What is the real solution?

There are a couple solutions that could work and not cause a mess, though I do not presume to know which is best:

1. Actually use the `package` metadata in the `.proto` files, some other python-specific field, or even a CLI argument (`--python_import_prefix`?) to define what the correct 
   absolute import path should be. That value in the above example would be `pb_generated`, so the generated files can contain `import pb_generated.bar_pb2 as bar__pb2`.

2. A more clever solution using Python 3's package loading mechanics (while simultaneously not requiring a package name like the prior solution) probably exists, but I do not 
   personally see how. Someone more competent than me may know better.

3. A refactor/rework of how `import` statements are generated in the Python plugin, so broken imports are not generated.

4. Document this quirk (the output directory needing to be in `PYTHONPATH` or `sys.path`) in the [tutorial](https://developers.google.com/protocol-buffers/docs/pythontutorial) 
or [reference guide](https://developers.google.com/protocol-buffers/docs/reference/python-generated). *This is the least the Protobuf team can do.*

## What are the workarounds?

### Workaround 1

Add a `__init__.py` file in the generated protobufs dir, containing:

    import sys
    from os import path

    sys.path.append(path.abspath(path.dirname(__file__)))

This adds the generated protobufs dir to `sys.path`, letting the protobufs find each other with absolute imports.

**Downside:** pollutes `sys.path`, and requires putting custom code in a generated code location.

### Workaround 2

Create a proxy package that imports and re-exports generated modules. Check `workaround-2/my_protos` to see what's going on.

**Downside:** Really janky. The proxy package also needs to be updated anytime a `.proto` file is added/removed/renamed.

### Workaround 3

Put all your Protobuf code in a single file. That way you can't get any import problems.

**Downside:** May result in a giant `.proto` file.