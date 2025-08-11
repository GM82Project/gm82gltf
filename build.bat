zig build --release=fast
@zig-out\fxc.exe /nologo /Tvs_3_0 vertex.hlsl /Fo zig-out\vertex.vs3
@zig-out\fxc.exe /nologo /Tps_3_0 pixel.hlsl /Fo zig-out\pixel.ps3
python zig-out\gm82gex.py gm82gltf.gej
pause