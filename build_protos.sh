#/bin/bash
set -ue;

targets=(
    broken
    workaround-1
    workaround-2
    workaround-3
);

echo Building docker protoc image
protoc_image=$(docker build -f ./Dockerfile.protoc -q .);
echo Built docker protoc image $protoc_image

for target in ${targets[@]}; do
    echo Building target: $target
    docker run -it \
        -v $PWD/$target/pb_sources:/opt/pb_sources \
        -v $PWD/$target/pb_generated:/opt/pb_generated \
        $protoc_image;
done
echo Done