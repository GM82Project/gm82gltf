#define __gltf_init
    globalvar __gm82gltf_bgpixel; __gm82gltf_bgpixel=background_create_color(1,1,c_white)
    globalvar __gm82gltf_texpixel; __gm82gltf_texpixel=background_get_texture(__gm82gltf_bgpixel)
    globalvar __gm82gltf_backgrounds;
    globalvar __gm82gltf_textures;
    globalvar __gm82gltf_meshes;
    globalvar __gm82gltf_meshid; __gm82gltf_meshid=0
    // stuff on primitives in meshes
    globalvar __gm82gltf_meshformats;
    globalvar __gm82gltf_meshindices;
    globalvar __gm82gltf_meshmodes;
    globalvar __gm82gltf_primitives;
    globalvar __gm82gltf_primitiveid; __gm82gltf_primitiveid=0
    // stuff on attributes in primitives
    globalvar __gm82gltf_primitivebuffers;

    globalvar __gm82gltf_shader_vertex_default; __gm82gltf_shader_vertex_default=shader_vertex_create_base64("
        eJyFVU1rFEEQff0xsyOi8wcE5xgVFhLxEPCgBkEkATWOeguriWQxZmUTQo6t5gcM
        mB+wB0+TSw7evPgbPHmMML8jLVVdvel1D9kc0l393uuq11W7Sp/7c38fKy8fProB
        4CcApc+9AUB7KOAHgDcANAAHYJviAA455mABHEnsWP4rAN9lPX46Gu7urw32x8ND
        nJycGBhYWFTxPBy9fvUM0zMVz9Y/DHcf7w7e7mxtEpeUw1/4HOxtLG0MsDZ8Nx7t
        jd7vVwsvblVPVtdXq/XtwebWuFoZffw03NkaV8v9peX+8r2l/t3FxUU8B7IjlBPA
        PUDyuTkts2xonQFOyVoDTstaAc6gbBYooaI7ywADlE6ja46ASZ91ylPgj8sAq1A4
        AzSm8hMApyGmOIaZmOaYSmKaua1wa8FZxukEZxhXC66VGN1Ryx0xRnfUckeMkV4t
        eu2pBoxC6RQ6Z9BxDZq1WtEKeWjWakUrxkirFa16qqXRsR5hwLl6ydUzD6zvRT/G
        SN+LfoyRvhd9z/rkPUT/Cu8V74GuCX71xOu/7Jfi91ROoXW0Jp8UasnturxBk2C1
        A7xgaV3zmt4LaGd4eoZnE55NeHaOZ2Z4RcIrEl4x5VmuqZaaWuZlUM5KTTmv05ro
        zZsEe1FTLjURtie6uuqm2BzW9QA+L+TczJwXruD5gDEouWdyfg+6h7ghp4xxLeO0
        9EQmOCtehjVxQs2WObVLe9JKHwUPqCd/c69d7kErHkTsxZ3zHlAPdwk25HThAc1k
        ej6fZ6wt+neZVzZ5k+BB9GPet+hBqIvmhurynIvl/g/+kR+kSdic86Z56hKsdrnk
        Rn7k0l85rsmcHSdYy9jg0VWZ4e3kvOA609ooz+hfLrWRV+Tl/30QZpdmPswuYXuc
        f/Chh5y9Sj3uTXmW98QL+4J1aX87/CbRd7IDvjV3ANB3NmmQ9md0E/piob0Dv6n0
        WYh94RjlHmJA+esrx8i3UB9gzhS6xnvgHw5sX8A=
    ")

    /*
        float4x4 rMatrixW, rMatrixWVP;
        float4x4 rJointMatrix[32];
        bool rSkinEnabled;
        
        struct VS_INPUT {
            float3 normal: NORMAL;
            float3 tangent: TANGENT0;
            float4 position: POSITION0;
            float2 texcoord: TEXCOORD0;
            int4 joints: BLENDINDICES0;
            float4 weights: BLENDWEIGHT0;
        };
        
        struct VS_OUTPUT {
            float4 position: POSITION0;
            float2 texcoord: TEXCOORD0;
        };
        
        VS_OUTPUT main(VS_INPUT input) {
            VS_OUTPUT output;
            if (rSkinEnabled) {
                float4x4 skin_mtx =
                    rJointMatrix[input.joints.x] * input.weights.x + 
                    rJointMatrix[input.joints.y] * input.weights.y +
                    rJointMatrix[input.joints.z] * input.weights.z +
                    rJointMatrix[input.joints.w] * input.weights.w;
                input.position = mul(skin_mtx, input.position);
                input.normal = mul(skin_mtx, float4(input.normal, 0)).xyz;
            }
        
            output.position = mul(rMatrixWVP, input.position);
            output.texcoord = input.texcoord;
        
            return output;
        }
    */

    globalvar __gm82gltf_shader_pixel_default; __gm82gltf_shader_pixel_default=shader_pixel_create_base64("
        eJxFj09qAjEUh78kIwxu5gKFztIWKoon6NgDdCG4rSWBiqIy/sFljjBHmP1sPFTO
        0UgysX1v8/2+x3skUnr/61+ZL96rJ8ACUnovgZAf9RE8IIDP5L4AldwhubpaHc18
        v93XdAKFIIvzv9nCXE/n2tB1XcYQEbuvy0bP9NvxZ6VNXU7H00k5Wq53pvw+7/TW
        6Jew89w/w4K6/XPRJG7Ii1ZELiy4JrBAWchugWXv2wqUoLACZ8ldO4hfSRlnHzmw
        xNl4M++z93AHuY45Nw==
    ")

    /*
        SamplerState rBaseTexture: register(s0);
        float4 rBaseColor;
        
        struct PS_INPUT {
            float2 texcoord: TEXCOORD0;
            float4 color: COLOR0;
        };
        
        struct PS_OUTPUT {
            float4 color: COLOR0;
        };
        
        PS_OUTPUT main(PS_INPUT input) {
            PS_OUTPUT output;
        
            float4 albedo = tex2D(rBaseTexture, input.texcoord);
        
            output.color = albedo * input.color * rBaseColor;
            
            return output;
        }
    */

    globalvar __gm82gltf_shader_vertex; __gm82gltf_shader_vertex=__gm82gltf_shader_vertex_default
    globalvar __gm82gltf_shader_pixel; __gm82gltf_shader_pixel=__gm82gltf_shader_pixel_default


#define gltf_load
    ///gltf_load(fn)
    var __i,__j,__k,__gltf,__texfile,__accessor,__stride;
    __gltf=__gltf_load(argument0)
    if (__gltf<0) return __gltf
    // load textures
    __i=0 repeat (gltf_texture_count(__gltf)) {
        __texfile=string_replace(gltf_texture_type(__gltf,__i),"image/",temp_directory+"\tmp.")
        gltf_texture_save(__gltf,__i,__texfile)
        __gm82gltf_backgrounds[__gltf,__i]=background_add(__texfile,false,false)
        __gm82gltf_textures[__gltf,__i]=background_get_texture(__gm82gltf_backgrounds[__gltf,__i])
        __i+=1
    }
    // create vertex buffers
    // __i: mesh
    __i=0 repeat (gltf_mesh_count(__gltf)) {
        __gm82gltf_meshes[__gltf,__i]=__gm82gltf_meshid
        // __j: primitive
        __j=0 repeat (gltf_mesh_primitive_count(__gltf,__i)) {
            __gm82gltf_primitives[__gm82gltf_meshid,__j]=__gm82gltf_primitiveid
            __gm82gltf_meshmodes[__gm82gltf_meshid,__j]=gltf_mesh_primitive_mode(__gltf,__i,__j)
            if (__gm82gltf_meshmodes[__gm82gltf_meshid,__j]<2)
                __gm82gltf_meshmodes[__gm82gltf_meshid,__j]-=1
            else if (__gm82gltf_meshmodes[__gm82gltf_meshid,__j]==2)
                {show_error("Line loops not supported.",true) exit}
            __accessor=gltf_mesh_primitive_indices_accessor(__gltf,__i,__j)
            if (__accessor>=0) {
                __gm82gltf_meshindices[__gm82gltf_meshid,__j]=__gltf_create_index_buffer(__gltf,__accessor)
            } else __gm82gltf_meshindices[__gm82gltf_meshid,__j]=-1
            // create vertex format
            vertex_format_begin()
            // __k: attribute
            __k=0 repeat (gltf_mesh_primitive_attribute_count(__gltf,__i,__j)) {
                __accessor=gltf_mesh_primitive_attribute_accessor(__gltf,__i,__j,__k)
                __gltf_format_add(
                    gltf_accessor_type(__gltf,__accessor),
                    gltf_accessor_component_type(__gltf,__accessor),
                    gltf_accessor_normalized(__gltf,__accessor),
                    gltf_mesh_primitive_attribute_semantic(__gltf,__i,__j,__k),
                    __k)
                __k+=1
            }
            __gm82gltf_meshformats[__gm82gltf_meshid,__j]=vertex_format_end()
            // create vertex buffers
            __k=0 repeat (gltf_mesh_primitive_attribute_count(__gltf,__i,__j)) {
                __accessor=gltf_mesh_primitive_attribute_accessor(__gltf,__i,__j,__k)
                __stride=gltf_accessor_stride(__gltf,__accessor)
                if (__stride<0) __stride=vertex_format_get_size(
                    __gm82gltf_meshformats[__gm82gltf_meshid,__j],
                    __k)
                __gm82gltf_primitivebuffers[__gm82gltf_primitiveid,__k]=
                    __gm82dx9_vertex_create_buffer_from_buffer(
                        gltf_accessor_pointer(__gltf,__accessor),
                        gltf_accessor_size(__gltf,__accessor),
                        __stride)
                __k+=1
            }
            __gm82gltf_primitiveid+=1
            __j+=1
        }
        __gm82gltf_meshid+=1
        __i+=1
    }
    return __gltf


#define __gltf_format_add
    ///__gltf_format_add(type,comptype,normalized,semantic,slot)
    var __type;
    switch (argument0) {
    case "SCALAR": if (argument1==5126) __type=vf_type_float1 break
    case "VEC2":
        switch (argument1) {
        case 5126: __type=vf_type_float2 break
        case 5122: if (argument2) __type=vf_type_short2n else __type=vf_type_short2 break
        case 5123: if (argument2) __type=vf_type_ushort2n break
        }
    break
    case "VEC3": if (argument1==5126) __type=vf_type_float3 break
    case "VEC4":
        switch (argument1) {
        case 5126: __type=vf_type_float4 break
        case 5122: if (argument2) __type=vf_type_short4n else __type=vf_type_short4 break
        // slightly cheating here and using signed shorts if not normalized
        case 5123: if (argument2) __type=vf_type_ushort4n else __type=vf_type_short4 break
        case 5121: if (argument2) __type=vf_type_ubyte4n else __type=vf_type_ubyte4 break
        }
    break
    }

    var __underscore; __underscore=string_pos("_",argument3)
    if (__underscore) argument3=string_copy(argument3,1,__underscore-1)
    var __usage;
    switch (string_copy(argument3,1,2)) {
    case "PO": __usage=vf_usage_position break
    case "NO": __usage=vf_usage_normal break
    case "TA": __usage=vf_usage_tangent break
    case "TE": __usage=vf_usage_texcoord break
    case "CO": __usage=vf_usage_color break
    case "JO": __usage=vf_usage_blendindices break
    case "WE": __usage=vf_usage_blendweight break
    }

    vertex_format_add_custom(__type,__usage,argument4)


#define __gltf_create_index_buffer
    ///__gltf_create_index_buffer(gltf,accessor)
    var __ibtype,__src,__dst,__address,__size,__ib;
    __type=gltf_accessor_component_type(argument0,argument1)
    __size=gltf_accessor_size(argument0,argument1)
    __src=-1
    __dst=-1
    if (__type==5123 || __type==5125) {
        // we can use the raw data
        if (__type==5123) __ibtype=ib_format_16
        else if (__type=5125) __ibtype=ib_format_32
        __address=gltf_accessor_pointer(argument0,argument1)
    } else {
        // needs converting
        __ibtype=ib_format_16
        __src=buffer_create()
        buffer_set_size(__src,__size)
        gltf_accessor_copy(argument0,argument1,buffer_get_address(__src,0),buffer_get_size(__src))
        __dst=buffer_create()
        buffer_set_pos(__src,0)
        if (__type==5121) {
            repeat (__size) {
                buffer_write_u16(__dst,buffer_read_u8(__src))
            }
        } else {
            show_error("Unknown index buffer type "+string(__type),true)
            exit
        }
        __address=buffer_get_address(__dst,0)
    }
    __ib=__gm82dx9_index_create_buffer_from_buffer(__address,__size,__ibtype)
    if (__src>=0) {buffer_destroy(__src) buffer_destroy(__dst)}
    return __ib


#define gltf_use_shader
    ///gltf_use_shader([vertex,pixel])
    if (argument_count<2) {
        __gm82gltf_shader_vertex=__gm82gltf_shader_vertex_default
        __gm82gltf_shader_pixel=__gm82gltf_shader_pixel_default
    } else {
        __gm82gltf_shader_vertex=argument[0]
        __gm82gltf_shader_pixel=argument[1]
    }


#define gltf_draw_scene
    ///gltf_draw_scene(gltf,scene)
    var __i;
    __i=0 repeat (gltf_scene_node_count(argument0,argument1)) {
        gltf_draw_node(argument0,gltf_scene_node(argument0,argument1,__i))
        __i+=1
    }


#define gltf_draw_node
    ///gltf_draw_node(gltf,node)
    var __i,__j,__k,__mesh_id,__cullmode,__unique_mesh_id,__skin,__joints,__jointsize,__address,__unique_primitive_id,__material,__base_texture_id,__base_texture;

    __mesh_id=gltf_node_mesh(argument0,argument1)
    if (__mesh_id<0 && gltf_node_child_count(argument0,argument1)<=0) exit;

    d3d_transform_stack_push()
    d3d_transform_set_scaling(gltf_node_sx(argument0,argument1),gltf_node_sy(argument0,argument1),gltf_node_sz(argument0,argument1))
    d3d_transform_add_rotation_axis(gltf_node_rx(argument0,argument1),gltf_node_ry(argument0,argument1),gltf_node_rz(argument0,argument1),-2*darccos(gltf_node_rw(argument0,argument1)))
    d3d_transform_add_translation(gltf_node_tx(argument0,argument1),gltf_node_ty(argument0,argument1),gltf_node_tz(argument0,argument1))
    d3d_transform_add_stack_top()

    // reversed from gltf spec because dx9 is left-handed
    if (d3d_transform_get_determinant()>0) __cullmode=cull_clockwise
    else __cullmode=cull_counterclockwise

    __skin=gltf_node_skin(argument0,argument1)
    if (__skin>=0) {
        __joints=gltf_skin_joints(argument0,__skin)
        __jointsize=4*4*4*gltf_skin_joint_count(argument0,__skin)
    }

    texture_set_repeat(true)
    if (__mesh_id>=0) {
        __unique_mesh_id=__gm82gltf_meshes[argument0,__mesh_id]
        __i=0 repeat (gltf_mesh_primitive_count(argument0,__mesh_id)) {
            __unique_primitive_id=__gm82gltf_primitives[__unique_mesh_id,__i]
            
            // set up material
            __material=gltf_mesh_primitive_material(argument0,__mesh_id,__i)

            if (gltf_material_double_sided(argument0,__material)) d3d_set_culling(false)
            else d3d_set_cull_mode(__cullmode)

            switch (gltf_material_alpha_mode(argument0,__material)) {
            case "BLEND": draw_set_blend_mode(bm_normal) break
            case "OPAQUE": d3d_set_alphablend(false) break
            case "MASK": d3d_set_alphatest(true,cm_greaterequal,gltf_material_alpha_cutoff(argument0,__material))
            }

            __base_texture_id=gltf_material_base_texture(argument0,__material)
            if (__base_texture_id>=0) __base_texture=__gm82gltf_textures[argument0,__base_texture_id]
            else __base_texture=__gm82gltf_texpixel

            shader_vertex_set(__gm82gltf_shader_vertex)

            __address=shader_vertex_uniform_get_address("rMatrixWVP")
            if (__address!=noone) shader_vertex_uniform_matrix(__address,mtx_world_view_projection)
            __address=shader_vertex_uniform_get_address("rMatrixW")
            if (__address!=noone) shader_vertex_uniform_matrix(__address,mtx_world)
            __address=shader_vertex_uniform_get_address("rSkinEnabled")
            if (__address!=noone) shader_vertex_uniform_b(__address,__skin>=0)
            if (__skin>=0) {
                __address=shader_vertex_uniform_get_address("rJointMatrix")
                __gm82dx9_shader_vertex_uniform_f_buffer(__address,__joints,__jointsize)
            }
            
            shader_pixel_set(__gm82gltf_shader_pixel)
            if (__material>=0) {
                __address=shader_pixel_uniform_get_address("rBaseColor")
                if (__address!=noone) __gm82dx9_shader_pixel_uniform_f_buffer(__address,gltf_material_base_color_pointer(argument0,__material),16)
            }
            
            // bind vertex buffers
            __j=gltf_mesh_primitive_attribute_count(argument0,__mesh_id,__i)-1 repeat (__j) {
                vertex_buffer_bind(__gm82gltf_primitivebuffers[__unique_primitive_id,__j],__j)
                __j-=1
            }
            // do final draw
            if (__gm82gltf_meshindices[__unique_mesh_id,__i]>=0)
                vertex_buffer_draw(
                    __gm82gltf_primitivebuffers[__unique_primitive_id,0],
                    __gm82gltf_meshformats[__unique_mesh_id,__i],
                    __gm82gltf_meshmodes[__unique_mesh_id,__i],
                    __base_texture,
                    __gm82gltf_meshindices[__unique_mesh_id,__i])
            else
                vertex_buffer_draw(
                    __gm82gltf_primitivebuffers[__unique_primitive_id,0],
                    __gm82gltf_meshformats[__unique_mesh_id,__i],
                    __gm82gltf_meshmodes[__unique_mesh_id,__i],
                    __base_texture)
            __i+=1
            
            shader_pixel_reset()
            d3d_set_alphablend(true)
            d3d_set_alphatest(false,0,0)
        }
    }

    __i=0 repeat (gltf_node_child_count(argument0,argument1)) {
        gltf_draw_node(argument0,gltf_node_child(argument0,argument1,__i))
        __i+=1
    }

    d3d_transform_stack_pop()

//
//