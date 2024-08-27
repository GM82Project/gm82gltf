#define __gltf_init
    globalvar __gm82gltf_bgpixel; __gm82gltf_bgpixel=background_create_color(1,1,c_white)
    globalvar __gm82gltf_texpixel; __gm82gltf_texpixel=background_get_texture(__gm82gltf_bgpixel)
    globalvar __gm82gltf_backgrounds;
    globalvar __gm82gltf_textures;
    globalvar __gm82gltf_meshlessnodes;
    globalvar __gm82gltf_meshes;
    globalvar __gm82gltf_meshid; __gm82gltf_meshid=0
    // stuff on primitives in meshes
    globalvar __gm82gltf_meshformats;
    globalvar __gm82gltf_meshindices;
    globalvar __gm82gltf_meshmodes;
    globalvar __gm82gltf_primitives;
    globalvar __gm82gltf_primitiveid; __gm82gltf_primitiveid=0
    globalvar __gm82gltf_primitive_hascolor;
    // stuff on attributes in primitives
    globalvar __gm82gltf_primitivebuffers;
    globalvar __gm82gltf_primitivemorphs;

    globalvar __gm82gltf_shader_vertex_default;
    __gm82gltf_shader_vertex_default=shader_vertex_create_file(temp_directory+"\gm82\gltf_vertex.vs3")

    globalvar __gm82gltf_shader_pixel_default;
    __gm82gltf_shader_pixel_default=shader_pixel_create_file(temp_directory+"\gm82\gltf_pixel.ps3")
    
    globalvar __gm82gltf_envmap_background,__gm82gltf_envmap_background_tex;
    __gm82gltf_envmap_background=background_add(temp_directory+"\gm82\envmap.jpg",0,0)
    __gm82gltf_envmap_background_tex=background_get_texture(__gm82gltf_envmap_background)

    globalvar __gm82gltf_shader_vertex; __gm82gltf_shader_vertex=__gm82gltf_shader_vertex_default
    globalvar __gm82gltf_shader_pixel; __gm82gltf_shader_pixel=__gm82gltf_shader_pixel_default
    
    globalvar __gm82gltf_lightbuffer; __gm82gltf_lightbuffer=buffer_create()

#define gltf_load
    ///gltf_load(fn)
    var __i,__j,__k,__gltf,__texfile,__accessor,__stride,__usage;
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
            __gm82gltf_primitive_hascolor[__gm82gltf_primitiveid]=false
            vertex_format_begin()
            // __k: attribute
            __k=0 repeat (gltf_mesh_primitive_attribute_count(__gltf,__i,__j)) {
                __accessor=gltf_mesh_primitive_attribute_accessor(__gltf,__i,__j,__k)
                __usage=__gltf_format_add(
                    gltf_accessor_type(__gltf,__accessor),
                    gltf_accessor_component_type(__gltf,__accessor),
                    gltf_accessor_normalized(__gltf,__accessor),
                    gltf_mesh_primitive_attribute_semantic(__gltf,__i,__j,__k),
                    __k
                )
                if (__usage==vf_usage_color) __gm82gltf_primitive_hascolor[__gm82gltf_primitiveid]=true
                __k+=1
            }
            repeat (min(3,gltf_mesh_primitive_morph_count(__gltf,__i,__j))) {
                vertex_format_add_custom(vf_type_float3,vf_usage_position,__k)
                vertex_format_add_custom(vf_type_float3,vf_usage_normal,__k+1)
                vertex_format_add_custom(vf_type_float3,vf_usage_tangent,__k+2)
                __k+=3
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
            // create vertex buffers for morph
            __k=0
            repeat (gltf_mesh_primitive_morph_count(__gltf,__i,__j)*3) {
                __accessor=gltf_mesh_primitive_morph(__gltf,__i,__j,__k div 3,__k mod 3)
                if (__accessor>=0) {
                    __stride=gltf_accessor_stride(__gltf,__accessor)
                    __gm82gltf_primitivemorphs[__gm82gltf_primitiveid,__k]=
                    __gm82dx9_vertex_create_buffer_from_buffer(
                        gltf_accessor_pointer(__gltf,__accessor),
                        gltf_accessor_size(__gltf,__accessor),
                        __stride)
                } else __gm82gltf_primitivemorphs[__gm82gltf_primitiveid,__k]=-1
                __k+=1
            }
            __gm82gltf_primitiveid+=1
            __j+=1
        }
        __gm82gltf_meshid+=1
        __i+=1
    }
    // identify childless nodes
    __gm82gltf_meshlessnodes[__gltf,gltf_node_count(__gltf)-1]=0
    var __stack;
    // __i: scene
    __i=0 repeat (gltf_scene_count(__gltf)) {
        // __j: node
        __j=0 repeat (gltf_scene_node_count(__gltf,__i)) {
            __gltf_identify_meshless(__gltf,gltf_scene_node(__gltf,__i,__j))
            __j+=1
        }
        __i+=1
    }
    return __gltf


#define __gltf_format_add
    ///__gltf_format_add(type,comptype,normalized,semantic,slot):usage
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
    
    return __usage


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


#define __gltf_identify_meshless
    ///__gltf_identify_meshless(gltf,node) -> meshless
    var __i,__meshless;
    __meshless=true
    __i=0 repeat (gltf_node_child_count(argument0,argument1)) {
        if (!__gltf_identify_meshless(argument0,gltf_node_child(argument0,argument1,__i))) __meshless=false
        __i+=1
    }
    if (gltf_node_mesh(argument0,argument1)>=0) __meshless=false
    __gm82gltf_meshlessnodes[argument0,argument1]=__meshless
    return __meshless


#define gltf_animate
    ///gltf_animate(gltf,animation,time)
    if (is_string(argument1)) return __gltf_animate(argument0,gltf_get_animation(argument0,argument1),argument2)
    else return __gltf_animate(argument0,argument1,argument2)


#define gltf_animation_length
    ///gltf_animation_length(gltf,animation)
    if (is_string(argument1)) return __gltf_animation_length(argument0,gltf_get_animation(argument0,argument1))
    else __gltf_animation_length(argument0,argument1)


#define gltf_use_shader
    ///gltf_use_shader([vertex,pixel])
    __gm82gltf_shader_vertex=__gm82gltf_shader_vertex_default
    __gm82gltf_shader_pixel=__gm82gltf_shader_pixel_default
    if (argument_count>=1) if (argument[0]>=0) __gm82gltf_shader_vertex=argument[0]
    if (argument_count>=2) if (argument[1]>=0) __gm82gltf_shader_pixel=argument[1]


#define gltf_draw_scene
    ///gltf_draw_scene(gltf,scene)
    var __i,__scene;
    if (is_string(argument1)) __scene=gltf_get_scene(argument0,argument1)
    else __scene=argument1
    __i=0 repeat (gltf_scene_node_count(argument0,__scene)) {
        gltf_draw_node(argument0,gltf_scene_node(argument0,__scene,__i))
        __i+=1
    }


#define gltf_set_environment_map
    ///gltf_set_environment_map(texture)
    if (argument0<0) __gm82gltf_envmap_background_tex=background_get_texture(__gm82gltf_envmap_background)
    else __gm82gltf_envmap_background_tex=argument0


#define gltf_draw_node
    ///gltf_draw_node(gltf,node)
    var __i,__j,__k,__node,__mesh_id,__cullmode,__unique_mesh_id,__skin,__joints,__jointsize,__address,__unique_primitive_id,__material,__hascolor;
    var __texture_id,__texture_base,__texture_norm,__texture_emi,__texture_occ,__texture_rough,__filter,__morph_count,__morph;

    if (is_string(argument1)) __node=gltf_get_node(argument0,argument1)
    else __node=argument1

    // if this node has no mesh and its children have no mesh, just give up
    if (__gm82gltf_meshlessnodes[argument0,argument1]) exit;

    __mesh_id=gltf_node_mesh(argument0,__node)

    __skin=gltf_node_skin(argument0,__node)
    if (__skin>=0) {
        __joints=gltf_skin_joints(argument0,__skin)
        __jointsize=4*4*4*gltf_skin_joint_count(argument0,__skin)
    }

    d3d_transform_stack_push()
    __gm82dx9_set_matrix_from_buffer(gltf_node_matrix_pointer(argument0,__node))
    d3d_transform_add_stack_top()

    // reversed from gltf spec because dx9 is left-handed
    if (d3d_transform_get_determinant()>0) __cullmode=cull_clockwise
    else __cullmode=cull_counterclockwise

    // "Only the joint transforms are applied to the skinned mesh; the transform of the skinned mesh node MUST be ignored."
    if (__skin>=0) {
        d3d_transform_stack_top()
    }

    __morph_count=gltf_node_weight_count(argument0,argument1)
    
    texture_set_repeat(true)
    if (__mesh_id>=0) {    
        shader_set(__gm82gltf_shader_vertex,__gm82gltf_shader_pixel)
    
        if (d3d_get_lighting()) {
            //bind lights
            var __i,__lb;
            
            __lb=__gm82gltf_lightbuffer
            buffer_get_lights(__lb)
            
            col_addr=shader_pixel_uniform_get_address("uLightColor")
            //pos_addr=shader_pixel_uniform_get_address("uLightPosRange")
            dir_addr=shader_pixel_uniform_get_address("uLightDirection")
            
            __i=0; repeat (8) {
                enabled=d3d_light_enabled(__i)
                if (enabled) {            
                    type=buffer_read_u32(__lb)
                    
                    colr=buffer_read_float(__lb)
                    colg=buffer_read_float(__lb)
                    colb=buffer_read_float(__lb)
                    
                    //skip over diffuse alpha and 2 more colors
                    buffer_set_pos(__lb,buffer_get_pos(__lb)+9*4)
                    
                    posx=buffer_read_float(__lb)
                    posy=buffer_read_float(__lb)
                    posz=buffer_read_float(__lb)
                    
                    dirx=buffer_read_float(__lb)
                    diry=buffer_read_float(__lb)
                    dirz=buffer_read_float(__lb)
                    
                    range=buffer_read_float(__lb)
                    
                    //skip rest of buffer
                    buffer_set_pos(__lb,buffer_get_pos(__lb)+6*4)
                    
                    shader_pixel_uniform_f(col_addr+__i,enabled*colr,enabled*colg,enabled*colb,1)
                    ///shader_pixel_uniform_f(pos_addr+__i,posx,posy,posz,(type==1)*range)
                    shader_pixel_uniform_f(dir_addr+__i,(type==3)*dirx,(type==3)*diry,(type==3)*dirz)
                } else buffer_set_pos(__lb,buffer_get_pos(__lb)+104)
            __i+=1}        
            
            shader_pixel_uniform_f("uLightingEnabled",1)
            shader_pixel_uniform_color("uAmbientColor",d3d_light_get_ambient())
            
            d3d_get_projection_origin()
            shader_pixel_uniform_f("uEyePos",d3d_get_projection_origin[0],d3d_get_projection_origin[1],d3d_get_projection_origin[2])
        } else shader_pixel_uniform_f("uLightingEnabled",0)
        //shader_pixel_uniform_f("uFogSettings",0,0,0)
        //shader_pixel_uniform_color("uFogColor",$ff00ff)
    
        __unique_mesh_id=__gm82gltf_meshes[argument0,__mesh_id]
        __i=0 repeat (gltf_mesh_primitive_count(argument0,__mesh_id)) {
            __unique_primitive_id=__gm82gltf_primitives[__unique_mesh_id,__i]
            
            // set up material
            __material=gltf_mesh_primitive_material(argument0,__mesh_id,__i)            
            __hascolor=__gm82gltf_primitive_hascolor[__unique_primitive_id]

            if (gltf_material_double_sided(argument0,__material)) d3d_set_culling(false)
            else d3d_set_cull_mode(__cullmode)

            switch (gltf_material_alpha_mode(argument0,__material)) {
                case "BLEND": draw_set_blend_mode(bm_normal) break
                case "OPAQUE": d3d_set_alphablend(false) break
                case "MASK": d3d_set_alphatest(true,cm_greaterequal,gltf_material_alpha_cutoff(argument0,__material)) break
            }

            __texture_id=gltf_material_base_texture     (argument0,__material) if (__texture_id>=0) __texture_base =__gm82gltf_textures[argument0,__texture_id] else __texture_base =__gm82gltf_texpixel
            __texture_id=gltf_material_normal_texture   (argument0,__material) if (__texture_id>=0) __texture_norm =__gm82gltf_textures[argument0,__texture_id] else __texture_norm = noone
            __texture_id=gltf_material_emissive_texture (argument0,__material) if (__texture_id>=0) __texture_emi  =__gm82gltf_textures[argument0,__texture_id] else __texture_emi  = noone
            __texture_id=gltf_material_occlusion_texture(argument0,__material) if (__texture_id>=0) __texture_occ  =__gm82gltf_textures[argument0,__texture_id] else __texture_occ  = noone
            __texture_id=gltf_material_roughness_texture(argument0,__material) if (__texture_id>=0) __texture_rough=__gm82gltf_textures[argument0,__texture_id] else __texture_rough= noone

            shader_vertex_uniform_matrix("uMatrixW",mtx_world)
            shader_vertex_uniform_matrix("uMatrixWVP",mtx_world_view_projection)
            
            shader_vertex_uniform_f("uSkinEnabled",__skin>=0)
            if (__skin>=0) {
                __gm82dx9_shader_vertex_uniform_f_buffer(shader_vertex_uniform_get_address("uJointMatrix"),__joints,__jointsize)
            }
            shader_vertex_uniform_f("uMorphCount",__morph_count)
            if (__morph_count>0) {
                __gm82dx9_shader_vertex_uniform_f_buffer(shader_vertex_uniform_get_address("uMorphWeights"),gltf_node_sorted_weights_pointer(argument0,argument1),4*3*min(3,gltf_mesh_primitive_morph_count(argument0,__mesh_id,__i)))
            }

            if (__material>=0) {
                __gm82dx9_shader_vertex_uniform_f_buffer(shader_vertex_uniform_get_address("uBaseColor"),gltf_material_base_color_pointer(argument0,__material),16)
            }
            
            shader_vertex_uniform_f("uHasVertexColor",__hascolor)

            // bind vertex buffers
            __j=gltf_mesh_primitive_attribute_count(argument0,__mesh_id,__i)-1 repeat (__j) {
                vertex_buffer_bind(__gm82gltf_primitivebuffers[__unique_primitive_id,__j],__j)
                __j-=1
            }
            __k=gltf_mesh_primitive_attribute_count(argument0,__mesh_id,__i)
            __j=0 repeat (gltf_mesh_primitive_morph_count(argument0,__mesh_id,__i)) {
                __morph=gltf_node_sorted_morph(argument0,argument1,__j)
                vertex_buffer_bind(
                    __gm82gltf_primitivemorphs[__unique_primitive_id,__morph*3],
                    __k+__j*3)
                vertex_buffer_bind(
                    __gm82gltf_primitivemorphs[__unique_primitive_id,__morph*3+1],
                    __k+__j*3+1)
                vertex_buffer_bind(
                    __gm82gltf_primitivemorphs[__unique_primitive_id,__morph*3+2],
                    __k+__j*3+2)
                __j+=1
            }
            
            // bind materials
            __filter=texture_get_interpolation()
            if (__texture_norm!=noone) {
                texture_set_stage("uNormTexture",__texture_norm)
                texture_set_stage_interpolation("uNormTexture",__filter)
                shader_pixel_uniform_f("uNormalMap_enabled",1)
            } else shader_pixel_uniform_f("uNormalMap_enabled",0)
            if (__texture_occ!=noone) {
                texture_set_stage("uOccTexture",__texture_occ)
                texture_set_stage_interpolation("uOccTexture",__filter)
                shader_pixel_uniform_f("uOcclusionMap_enabled",1)
            } else shader_pixel_uniform_f("uOcclusionMap_enabled",0)
            if (__texture_emi!=noone) {
                texture_set_stage("uEmissiveTexture",__texture_emi)
                texture_set_stage_interpolation("uEmissiveTexture",__filter)
                shader_pixel_uniform_f("uEmissiveMap_enabled",1)
            } else shader_pixel_uniform_f("uEmissiveMap_enabled",0)
            if (__texture_rough!=noone) {
                texture_set_stage("uRoughTexture",__texture_rough)
                texture_set_stage_interpolation("uRoughTexture",__filter)
                texture_set_stage("uEnvMap",__gm82gltf_envmap_background_tex)
                texture_set_stage_interpolation("uEnvMap",1)
                shader_pixel_uniform_matrix("uMatrixV",mtx_view)                 
                shader_pixel_uniform_f("uRoughnessMap_enabled",1)
            } else shader_pixel_uniform_f("uRoughnessMap_enabled",0)
            
            // do final draw
            if (__gm82gltf_meshindices[__unique_mesh_id,__i]>=0)
                vertex_buffer_draw(
                    __gm82gltf_primitivebuffers[__unique_primitive_id,0],
                    __gm82gltf_meshformats[__unique_mesh_id,__i],
                    __gm82gltf_meshmodes[__unique_mesh_id,__i],
                    __texture_base,
                    __gm82gltf_meshindices[__unique_mesh_id,__i])
            else
                vertex_buffer_draw(
                    __gm82gltf_primitivebuffers[__unique_primitive_id,0],
                    __gm82gltf_meshformats[__unique_mesh_id,__i],
                    __gm82gltf_meshmodes[__unique_mesh_id,__i],
                    __texture_base)
            __i+=1
            
            d3d_set_alphablend(true)
            d3d_set_alphatest(false,0,0)
        }
    }

    d3d_transform_stack_pop()
    
    shader_reset()

    __i=0 repeat (gltf_node_child_count(argument0,__node)) {
        gltf_draw_node(argument0,gltf_node_child(argument0,__node,__i))
        __i+=1
    }

//
//