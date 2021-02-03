from google.protobuf.json_format import MessageToJson

from pb_generated.foo_pb2 import Foo

foo = Foo()
foo.bar.greeting = 'hello world'
print('Foo proto successfully serialized to:', MessageToJson(foo))