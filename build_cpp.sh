#!/bin/bash

whisper_path="$1"
targets=${2:-all}
android_sdk_path="$3"
unity_project="$PWD"
build_path="$1/build"

clean_build(){
  rm -rf "$build_path"
  mkdir "$build_path"
  cd "$build_path"
}

build_mac() {
  clean_build
  echo "Starting building for Mac (Metal)..."

  cmake -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" -DGGML_METAL=ON -DCMAKE_BUILD_TYPE=Release  \
   -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF -DGGML_METAL_EMBED_LIBRARY=ON ../
  make

  echo "Build for Mac (Metal) complete!"

  rm $unity_project/Packages/com.whisper.unity/Plugins/MacOS/*.dylib

  artifact_path="$build_path/src/libwhisper.dylib"
  target_path="$unity_project/Packages/com.whisper.unity/Plugins/MacOS/libwhisper.dylib"
  cp "$artifact_path" "$target_path"

  artifact_path=$build_path/ggml/src
  target_path=$unity_project/Packages/com.whisper.unity/Plugins/MacOS/
  cp "$artifact_path"/*.dylib "$target_path"
  cp "$artifact_path"/*/*.dylib "$target_path"

  # Required by Unity to properly find the dependencies
  for file in "$target_path"*.dylib; do
    install_name_tool -add_rpath @loader_path $file
  done

  echo "Build files copied to $target_path"
}

build_ios() {
  clean_build
  echo "Starting building for ios..."

  cmake -DBUILD_SHARED_LIBS=OFF -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_BUILD_TYPE=Release  \
  -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" -DGGML_METAL=ON \
  -DCMAKE_SYSTEM_PROCESSOR=arm64 -DCMAKE_IOS_INSTALL_COMBINED=YES \
  -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=OFF ../
  make

  echo "Build for ios complete!"

  rm $unity_project/Packages/com.whisper.unity/Plugins/iOS/*.a

  artifact_path="$build_path/src/libwhisper.a"
  target_path="$unity_project/Packages/com.whisper.unity/Plugins/iOS/libwhisper.a"
  cp "$artifact_path" "$target_path"

  artifact_path=$build_path/ggml/src
  target_path=$unity_project/Packages/com.whisper.unity/Plugins/iOS/
  cp "$artifact_path"/*.a "$target_path"
  cp "$artifact_path"/*/*.a "$target_path"

  echo "Build files copied to $target_path"
}

build_android() {
  clean_build
  echo "Starting building for Android..."
  
  # Clone Vulkan-Hpp at v1.3.237 for PipelineRobustness support
  echo "Cloning Vulkan-Hpp repository (v1.3.237 for ggml-vulkan compatibility)..."
  
  VULKAN_VERSION="v1.3.237"  # Change this to test different versions
  
  if ! git clone --depth 1 --branch $VULKAN_VERSION https://github.com/KhronosGroup/Vulkan-Hpp.git vulkan_hpp_temp; then
    echo "ERROR: Could not clone Vulkan-Hpp $VULKAN_VERSION"
    exit 1
  fi
  
  # Copy the vulkan directory with all headers
  mkdir -p vulkan_headers
  cp -r vulkan_hpp_temp/vulkan vulkan_headers/
  
  # Clean up temporary clone
  rm -rf vulkan_hpp_temp
  
  echo "✓ Vulkan C++ binding headers ($VULKAN_VERSION) copied successfully"
  
  cmake -DCMAKE_TOOLCHAIN_FILE="$android_sdk_path" \
  -DANDROID_PLATFORM=android-24 \
  -DANDROID_ABI=arm64-v8a \
  -DGGML_VULKAN=ON \
  -DGGML_OPENMP=OFF \
  -DBUILD_SHARED_LIBS=OFF \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_EXAMPLES=OFF \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_FLAGS="-I${build_path}/vulkan_headers" \
  ../
  
  make
  echo "Build for Android complete!"
  rm -f $unity_project/Packages/com.whisper.unity/Plugins/Android/*.a
  artifact_path="$build_path/src/libwhisper.a"
  target_path="$unity_project/Packages/com.whisper.unity/Plugins/Android/libwhisper.a"
  cp "$artifact_path" "$target_path"
  artifact_path=$build_path/ggml/src
  target_path=$unity_project/Packages/com.whisper.unity/Plugins/Android/
  cp "$artifact_path"/*.a "$target_path" 2>/dev/null || true
  cp "$artifact_path"/*/*.a "$target_path" 2>/dev/null || true
  echo "Build files copied to $target_path"
}
if [ "$targets" = "all" ]; then
  build_mac
  build_ios
  build_android
elif [ "$targets" = "mac" ]; then
  build_mac
elif [ "$targets" = "ios" ]; then
  build_ios
elif [ "$targets" = "android" ]; then
  build_android
else
  echo "Unknown targets: $targets"
fi
