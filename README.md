# Game Maker 8.2 glTF

This extension allows for using the glTF model format in Game Maker 8.2. It is currently compatible with glTF files exported from Blender; if you've got a glTF that displays incorrectly, please file an issue or pull request.

Important functions include:
* `gltf_load(filename: str) -> gltf` - load a glTF from a file. Note that only `.glb` is supported, with no external resources.
* `gltf_use_shader([vertex,pixel])` - Set the shader to use. Omitting both arguments sets a default shader.
* `gltf_scene(gltf)` - Gets the default scene of this glTF.
* `gltf_draw_scene(gltf,scene)` - Draws all nodes in a glTF scene. Any existing transform will still be applied. Scene names and IDs are both accepted.
* `gltf_draw_node(gltf,node)` - Draws a specific node. Any existing transform will still be applied. Node names and IDs are both accepted.
* `gltf_animate(gltf,animation,time)` - Sets up an animation at the given timestamp (in seconds). Animation names and IDs are both accepted. Returns 1 when the animation has finished, and 0 when it hasn't.
* `gltf_animation_length(gltf,animation)` - Returns the timestamp of the last keyframe of the given animation, in seconds. Animation names and IDs are both accepted.
