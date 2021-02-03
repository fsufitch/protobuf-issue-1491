#/bin/bash

set -ue;

targets=(
    broken
    workaround-1
    workaround-2
    workaround-3
);

for target in ${targets[@]}; do
    echo =====
    echo Building runner image for target: $target
    image=$(docker build -f Dockerfile.runner -q --build-arg TARGET=$target .)
    echo Built image for $target: $image
    echo Running $image
    docker run $image || echo "Exited with non-zero status"
done