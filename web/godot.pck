GDPC                   	                                                                         X   res://.godot/exported/133200997/export-128d0d3707d7b3a2422f44dcb72e71e4-main_panel.scn  �]      ()      ��2���%�d`����    d   res://.godot/exported/133200997/export-a46938bc29a316f6833b00cdec411d91-test_raytracing_scene.scn   @�      	      ÚxЃx�6����b�    D   res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex@�      ^      2��r3��MgB�[79       res://.godot/uid_cache.bin  0�      �       �?��)���u�9�d    (   res://addons/RayTracing/RayTracing.gd   ��      I      ����~3�.1�8�<�    (   res://addons/RayTracing/main_panel.gd   �U            �q�k
٩;e�s#hE�    0   res://addons/RayTracing/main_panel.tscn.remap   ��      g       �j���V�0#�u=    8   res://addons/RayTracing/shaders/post_processing.gdshader        �       _�>�F�{k�rۂ&&    8   res://addons/RayTracing/shaders/raytracing_pbr.gdshader �       �@      w��q�7���P%Yj    8   res://addons/RayTracing/shared/script/FreeCamera3D.gd    H      �      ǵ�&�����]f�    D   res://addons/RayTracing/shared/script/always/alwasy_fill_viewport.gdpA      �       �0O�t9j��JT�    H   res://addons/RayTracing/shared/script/always/always_shader_backbuffer.gd0B            o�!�8|�\ӽ��'���    H   res://addons/RayTracing/shared/script/always/always_uniform_camera.gd   @D      �      ��[$��_��O�    8   res://addons/RayTracing/theme/ui_style_box_flat.stylebox�S      �      ��9�Ff+��DH�q       res://icon.svg  ��      N      ]��s�9^w/�����       res://icon.svg.import   ��      C      ��G�8����L^�Uj       res://project.binary �      M      m3���Tz��h���    4   res://test/scenes/test_raytracing_scene.tscn.remap  `�      r       �o�/dnb������    (   res://test/scripts/OldFreeCamera3D.gd   ��      �	      ����8۟�TR���    8   res://test/scripts/always/always_shader_backbuffer.gd   P�      �      ZIs�v���8�1B"    8   res://test/scripts/always/always_shader_camera_pos.gd    �      �      !K&h4���+~�Y��>    0   res://test/shaders/camera_raytracing.gdshader   ��      2'      ���G�C�bc��6�9    ,   res://test/shaders/test_backbuffer.gdshader ��      �       �_�lY�H�-���	H    (   res://test/shaders/test_gamma.gdshader  ��      r       4���w�=oy�N6M    shader_type canvas_item;

uniform float frame = 1.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    vec4 back = texture(SCREEN_TEXTURE, SCREEN_UV);

    COLOR = mix(back, color, 1.0 / max(1.0, frame));
}�A�fshader_type canvas_item;

// 传入统一值
uniform vec3 camera_position    = vec3(0.0, 0.0, 4.0);  // 传入摄像机的位置
uniform mat3 camera_rotation    = mat3(1);              // 摄像机的旋转
uniform float camera_aspect     = 2.0;                  // 画布长宽比
uniform float camera_vfov       = 30.0;                 // 摄像机的纵向视野
uniform float camera_focus      = 2.0;                  // 摄像机的对焦距离
uniform float camera_aperture   = 0.005;                // 摄像机的光圈大小
uniform float camera_gamma      = 0.2;                  // gamma 矫正值

// 配置常量
const float TMIN        = 0.001;                        // 光开始传播的起始偏移，避免光线自相交
const float TMAX        = 2000.0;                       // 最大单次光线传播距离
const float PRECISION   = 0.00001;                      // 必须要小于 TMIN，否则光线会自相交产生阴影痤疮
const float MAP_SIZE    = float(0x7fffffff);            // 地图大小

const uint MAX_RAYMARCH = 512U;                         // 最大光线步进次数
const uint MAX_RAYTRACE = 512U;                         // 最大光线追踪次数

const float ENV_IOR = 1.0;                              // 环境的折射率

// 光线
struct ray {
    vec3 origin;        // 光的起点
    vec3 direction;     // 光的方向
    vec4 color;         // 光的颜色
};

// 物体材质
struct material {
    vec3 albedo;        // 反照率
    float roughness;    // 粗糙度
    float metallic;     // 金属度
    float transmission; // 透明度
    float ior;          // 折射率
    vec4 emission;      // 自发光 (RGB, Intensity)
    vec3 normal;        // 切线空间法线
};

// 光子击中的记录
struct record {
    bool hit;           // 是否击中
    float t;            // 沿射线前进的距离
    float sd;           // 击中位置距离表面 (为负代表在物体内部)
    vec3 position;      // 击中的位置
    vec3 normal;        // 击中位置的法线
    material mtl;       // 击中的材质
};

// SDF 物体
struct object {
    float sd;           // 到物体表面的距离
    material mtl;       // 物体的材质
};

// 摄像机
struct camera {
    vec3 lookfrom;      // 视点位置
    vec3 lookat;        // 目标位置
    vec3 vup;           // 向上的方向
    float vfov;         // 视野
    float aspect;       // 传感器长宽比
    float aperture;     // 光圈大小
    float focus;        // 对焦距离
};

// 随机发生器
struct random {
    float seed;         // 随机数种子
    float value;        // 上次的随机值
};

// 对三维向量进行哈希
float hash(vec3 x) {
    uvec3 p = floatBitsToUint(x);
    p = 1103515245U * ((p.xyz >> 1U) ^ (p.yzx));
    uint h32 = 1103515245U * ((p.x ^ p.z) ^ (p.y >> 3U));
    uint n = h32 ^ (h32 >> 16U);
    return float(n) * (1.0 / float(0x7fffffff));
}

// 生成归一化随机数
float noise(inout random r) {
    r.value = fract(sin(r.seed++)*43758.5453123);
    return r.value;
}

// 光子在射线所在的位置
vec3 at(ray r, float t) {
    return r.origin + t * r.direction;
}

// 单位圆内随机取一点
vec2 random_in_unit_disk(inout random seed) {
    float r = noise(seed);
    float a = TAU * noise(seed);
    return r * vec2(sin(a), cos(a));
//    return sqrt(r) * vec2(sin(a), cos(a));
}

// 从摄像机获取光线
ray get_ray(camera c, vec2 uv, vec4 color, inout random rand) {
    // 根据 VFOV 和显示画布长宽比计算传感器长宽
    float theta = c.vfov * PI / 180.0;
    float half_height = tan(theta / 2.0);
    float half_width = c.aspect * half_height;
    
    // 以目标位置到摄像机位置为 Z 轴正方向
    vec3 z = normalize(c.lookfrom - c.lookat);
    // 计算出摄像机传感器的 XY 轴正方向
    vec3 x = normalize(cross(c.vup, z));
    vec3 y = cross(z, x);
    
    vec3 lower_left_corner = c.lookfrom - half_width  * c.focus*x
                                        - half_height * c.focus*y
                                        -               c.focus*z;
    
    vec3 horizontal = 2.0 * half_width  * c.focus * x;
    vec3 vertical   = 2.0 * half_height * c.focus * y;
    
    // 模拟光进入镜头光圈
    float lens_radius = c.aperture / 2.0;
    vec2 rud = lens_radius * random_in_unit_disk(rand);
    vec3 offset = x * rud.x + y * rud.y;
    
    // 计算光线起点和方向
    vec3 ro = c.lookfrom + offset;
    vec3 po = lower_left_corner + uv.x*horizontal 
                                + uv.y*vertical;
    vec3 rd = normalize(po - ro);
    
    return ray(ro, rd, color);
}

// SDF 球体
float sphere(vec3 p, float s) {
    return length(p) - s;
}

// SDF 盒子
float box(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0)) + min(max(q.x, max(q.y, q.z)), 0);
}

// SDF 圆柱
float cylinder(vec3 p, float h, float r) {
    vec2 d = abs(vec2(length(p.xz),p.y)) - vec2(r, h);
    return min(max(d.x,d.y), 0.0) + length(max(d, 0.0));
}

// SDF 地图
object map(vec3 p) {
    object objs[] = {
        object(sphere(p - vec3(0, -100.5, 0), 100),
                        material(vec3(1.0, 1.0, 1.0)*0.3,
                                    1.0, // 粗糙度
                                    0.0, // 金属度
                                    0.0, // 透明度
                                    1.0, // 折射率
                                    vec4(0),
                                    vec3(0, 0, 1)
                        )
        ),
        object(sphere(p - vec3(0, 0, 0), 0.5),
                        material(vec3(1.0, 1.0, 1.0),
                                    1.0, // 粗糙度
                                    0.0, // 金属度
                                    0.0, // 透明度
                                    1.0, // 折射率
                                    vec4(0.1, 1.0, 0.1, 10.0),
                                    vec3(0, 0, 1)
                        )
        ),
        object(sphere(p - vec3(-1.0, -0.2, 0), 0.3),
                        material(vec3(1.0, 0.1, 0.1),
                                    0.9, // 粗糙度
                                    0.1, // 金属度
                                    0.0, // 透明度
                                    1.0, // 折射率
                                    vec4(0),
                                    vec3(0, 0, 1)
                        )
        ),
        object(sphere(p - vec3(1.0, -0.2, 0), 0.3),
                        material(vec3(0.1, 0.1, 1.0),
                                    0.3, // 粗糙度
                                    1.0, // 金属度
                                    0.0, // 透明度
                                    1.0, // 折射率
                                    vec4(0),
                                    vec3(0, 0, 1)
                        )
        ),
        object(box(p - vec3(0, 0, -1), vec3(2, 1, 0.2)),
                        material(vec3(1.0, 1.0, 1.0),
                                    0.1, // 粗糙度
                                    0.9, // 金属度
                                    0.0, // 透明度
                                    1.0, // 折射率
                                    vec4(0),
                                    vec3(0, 0, 1)
                        )
        ),
        object(cylinder(p - vec3(0, 0.1, 1), 0.5, 0.2),
                        material(vec3(1.0, 1.0, 0.1),
                                    0.0, // 粗糙度
                                    1.0, // 金属度
                                    0.0, // 透明度
                                    1.0, // 折射率
                                    vec4(0),
                                    vec3(0, 0, 1)
                        )
        ),
        object(cylinder(p - vec3(0, 0.0, -2), 0.6, 0.5),
                        material(vec3(1.0, 0.0, 1.0),
                                    1.0, // 粗糙度
                                    1.0, // 金属度
                                    0.0, // 透明度
                                    1.0, // 折射率
                                    vec4(0),
                                    vec3(0, 0, 1)
                        )
        ),
        object(sphere(p - vec3(1.0, -0.2, 1), 0.3),
                        material(vec3(1.0, 1.0, 1.0),
                                    0.0, // 粗糙度
                                    0.0, // 金属度
                                    1.0, // 透明度
                                    1.25, // 折射率
                                    vec4(0),
                                    vec3(0, 0, 1)
                        )
        ),
        object(sphere(p - vec3(-1.0, -0.2, 1), 0.3),
                        material(vec3(0.0, 1.0, 1.0),
                                    0.0, // 粗糙度
                                    0.0, // 金属度
                                    1.0, // 透明度
                                    1.25, // 折射率
                                    vec4(0),
                                    vec3(0, 0, 1)
                        )
        )
    };
    
    // 返回距离最近的那个物体
    object o; o.sd = MAP_SIZE;
    for (int i = 0; i < objs.length(); i++) {
        object oi = objs[i];
        if (oi.sd < o.sd) o = oi;
    }

    return o;
}

// 计算地图法线 (这里还可以优化，因为计算法线不应该再次寻找最近物体)
vec3 calc_normal(vec3 p) {
    vec2 e = vec2(1, -1) * 0.5773 * 0.0005;
    return normalize( e.xyy*map( p + e.xyy ).sd + 
                      e.yyx*map( p + e.yyx ).sd + 
                      e.yxy*map( p + e.yxy ).sd + 
                      e.xxx*map( p + e.xxx ).sd );
}

// 用世界坐标下的法线计算 TBN 矩阵
mat3 TBN(vec3 N) {
    vec3 T, B;
    
    if (N.z < -0.999999) {
        T = vec3(0, -1, 0);
        B = vec3(-1, 0, 0);
    } else {
        float a = 1.0 / (1.0 + N.z);
        float b = -N.x*N.y*a;
        
        T = vec3(1.0 - N.x*N.x*a, b, -N.x);
        B = vec3(b, 1.0 - N.y*N.y*a, -N.y);
    }
    
    return mat3(T, B, N);
}

// 光线步进
record raycast(ray r) {
    record rec; rec.t = TMIN;
    for(uint i = 0U; i < MAX_RAYMARCH && rec.t < TMAX; i++) {
        rec.position = at(r, rec.t);
        object obj = map(rec.position);
        if (abs(obj.sd) < PRECISION) {
            rec.mtl = obj.mtl;
            rec.sd = obj.sd;
            rec.hit = true;
            return rec;
        }
        rec.t += abs(obj.sd);
    }
    // 没有击中物体
    rec.hit = false;
    return rec;
}

// 天空
vec4 sky(ray r) {
    float t = 0.5 + 0.5 * r.direction.y;
    vec4 bottom = vec4(1.0, 1.0, 1.0, 1.0);
    vec4 top = vec4(0.5, 0.7, 1.0, 1.0);
    return mix(bottom, top, t);
}

// 快速计算五次方
float pow5(float x) {
    float t = x*x;
    t *= t;
    return t*x;
}

// 用粗糙度计算菲涅尔近似值
float fresnel_schlick(float cosine, float F0, float X) {
    return F0 + (max(1.0 - X, F0) - F0) * pow5(abs(1.0 - cosine));
}

// 以 n 为法线进行半球采样
vec3 hemispheric_sampling(vec3 n, inout random rand) {
    float ra = TAU * noise(rand);
    float rb = noise(rand);
    
    vec2 v = vec2(cos(ra), sin(ra));
    vec2 rxy = sqrt(rb) * v; 
    float rz = sqrt(1.0 - rb);
    
    return TBN(n) * vec3(rxy, rz);
}

// 用粗糙度采样沿向量 n 采样
vec3 hemispheric_sampling_roughness(vec3 n, float roughness, inout random rand) {
    float ra = TAU * noise(rand);
    float rb = noise(rand);

    // 光感越大高光越锐利
    float shiny = pow5(roughness);
    
    float rz = sqrt((1.0 - rb) / (1.0 + (shiny - 1.0)*rb));
    vec2 v = vec2(cos(ra), sin(ra));
    vec2 rxy = sqrt(abs(1.0 - rz*rz)) * v;
    
    return TBN(n) * vec3(rxy, rz);
}

// 应用 PBR 材质
ray PBR(ray r, inout record rec, inout random rand) {
    // 材质参数
    vec3 albedo = rec.mtl.albedo;
    float roughness = rec.mtl.roughness;
    float metallic = rec.mtl.metallic;
    float transmission = rec.mtl.transmission;
    vec3 normal = rec.mtl.normal;
    float ior = rec.mtl.ior;
    
    // 光线和物体表面参数
    vec3 V  = -r.direction;
    vec3 P  = rec.position;
    vec3 N  = TBN(normal) * calc_normal(P);
    vec3 C  = r.color.rgb;
    vec3 L;
    
    float NoV = dot(N, V);
    
    rec.normal = N;

    // 对透明度的处理可能还有问题
    if (noise(rand) < transmission) {
        C *= albedo;
        
        // 折射率之比
        float eta;
        
        if (NoV < 0.0) {
            // 处于 SDF 物体内部
            eta = ior / ENV_IOR;
            N = -N;
        } else {
            eta = ENV_IOR / ior;
        }
        
        const float F0 = 0.08;
        float F = fresnel_schlick(NoV, F0, ior);
        N = hemispheric_sampling_roughness(N, roughness, rand);
        if (noise(rand) < F + metallic) {
            L = reflect(r.direction, N);
            r.color.a *= (sign(dot(L, N)) + 1.0) * 0.5;
        } else {
            L = refract(r.direction, N, eta);
            L = -L * sign(dot(L, N));
  
        }
    } else {
        const float F0 = 0.04;
        float F = fresnel_schlick(NoV, F0, roughness);
    
        // 反射或者漫反射
        if (noise(rand) < F + metallic) {
            C *= albedo; 
            N = hemispheric_sampling_roughness(N, roughness, rand);
            L = reflect(r.direction, N);
        } else {
            // 漫反射
            C *= albedo;
            L = hemispheric_sampling(N, rand);
        }

        // 如果光射到表面下面就直接吸收掉
        if (dot(L, N) < 0.0) {
            r.color.a = 0.0;
        }
    }

    // 更新光的方向和颜色
    r.color.rgb = C;
    r.origin = P;
    r.direction = L;
    
//    r.color.rgb = vec3(F);
//    r.color.a = 1.0;
    
    return r;
}

// 光线追踪
ray raytrace(ray r, inout random rand) {
    for (uint i = 0U; i < MAX_RAYTRACE; i++) {
        record rec = raycast(r);
        
        // 没击中物体就肯定击中天空
        if (!rec.hit) {
            r.color *= sky(r);
//            r.color *= 0.0;
            break;
        }
        
        r = PBR(r, rec, rand);
        
//        r.color.rgb = 0.5 + 0.5*rec.normal;
//        r.color.a = 1.0;
//        break;
        
        // 光被吸收完了就不用继续了
        if (r.color.a <= 0.0) {
            break;
        }
        
        // 处理自发光
        if (abs(rec.mtl.emission.a) > 0.0) {
            r.color.rgb *= rec.mtl.emission.rgb*rec.mtl.emission.a;
            break;
        }
    }

    return r;
}

// 一次采样
vec3 sample(camera cam, vec2 uv, vec4 color, inout random rand) {
    // 获取光线并逆向追踪光线
    ray r = get_ray(cam, uv, color, rand);
        r = raytrace(r, rand);
    
    // 对光的颜色进行后处理得到像素颜色
    return r.color.rgb * r.color.a;
}

// HDR 映射色彩
vec3 HDR(vec3 color) {
    return vec3(1) - exp(-color);
}

// 片段着色器程序入口
void fragment() {
    // 计算并修正 UV 坐标系 (左手系，以左下角为原点)
    vec2 uv = vec2(UV.x, 1.0 - UV.y);
    
    // 计算摄像机方位和视线
    vec3 lookfrom = camera_position;
    vec3 direction = camera_rotation * vec3(0, 0, -1);
    vec3 lookat = lookfrom + direction;
    
    // 初始化摄像机
    camera cam;
    cam.lookfrom = lookfrom;
    cam.lookat = lookat;
    cam.aspect = camera_aspect;
    cam.vfov = camera_vfov;
    cam.vup = vec3(0, 1, 0);
    cam.focus = camera_focus;
    cam.aperture = camera_aperture;
    
    // 用 UV 和时间初始化随机数发生器种子
    random rand;
    rand.seed  = hash(vec3(uv, TIME));
    
    // 对每个光子经过的表面采样一次
    vec3 color = sample(cam, uv, vec4(1), rand);
    
//    vec2 oz = vec2(1, 0);
//    vec3 R = sample(cam, uv, oz.xyyx, rand);
//    vec3 G = sample(cam, uv, oz.yxyx, rand);
//    vec3 B = sample(cam, uv, oz.yyxx, rand);
//
//    color = (R + G + B) / 3.0;
    
    // 单帧内多重采样
//    const uint N = 10U;
//    for (uint i = 0U; i < N; i++) {
//        color += sample(cam, uv, vec4(1), rand);
//    }
//    color = color / float(N + 1U);
    
    // HDR 映射色彩
    color = HDR(color);
    // 伽马矫正
    color = pow(color, vec3(camera_gamma));
    
    // 测试随机数
//    color = vec3(noise(rand), noise(rand), noise(rand));
    COLOR = vec4(color, 1.0);
}@tool

extends Node

@onready var control: Control = $".."
@onready var viewport: SubViewport = $"../.."

func _process(_delta: float) -> void:
    control.size = viewport.size
�]dޚl��4�+�Vextends Node

@onready var camera: OldFreeCamera3D = %FreeCamera3D

var material: ShaderMaterial
var textureRect: TextureRect

var image: Image

var frame: float = 0


func _ready() -> void:
    textureRect = get_parent()
    material = textureRect.material


func _process(_delta: float) -> void:
    if is_instance_valid(camera):
        if camera.moving:
            frame = 0
    if Input.is_action_pressed("ui_accept"):
        frame = 0

    frame += 1

    material.set_shader_parameter(
        "frame", frame)
����ĭ^�@tool

extends Node

@onready var camera: FreeCamera3D = %FreeCamera3D

var material: ShaderMaterial
var control: Control

var gamma: float = 0.5
var focus: float = 2.0
var aperture: float = 0.005

func _ready() -> void:
    control = get_parent() as Control
    material = get_parent().material


func _process(_delta: float) -> void:
    var camera_position := camera.transform.origin
    var camera_rotation := camera.transform.basis
    var aspect := control.size.x / control.size.y
    var vfov := camera.fov


    material.set_shader_parameter("camera_position", camera_position)
    material.set_shader_parameter("camera_rotation", camera_rotation)
    material.set_shader_parameter("camera_aspect", aspect)
    material.set_shader_parameter("camera_vfov", vfov)
    material.set_shader_parameter("camera_gamma", gamma)
    material.set_shader_parameter("camera_focus", focus)
    material.set_shader_parameter("camera_aperture", aperture)
t^�0��X�Ď�@tool

class_name FreeCamera3D

extends Camera3D

@export_range(0, 10, 0.01) var sensitivity:float = 3
@export_range(0, 1000, 0.1) var velocity:float = 5
@export_range(0, 1, 0.0001) var acceleration:float = 0.01
@export_range(0, 10, 0.01) var speed_scale:float = 1.01
@export var max_speed:float = 1000
@export var min_speed:float = 0.0
@export_range(0, 100, 0.01) var smooth:float = 10
@export var restric: bool = true

@onready var control: Control = %Control

var captured: bool = false
var captured_position: Vector2
var moving: bool = false

var _velocity: float = 0.0;
var _translate: Vector3 = Vector3()
var _rotation: Vector3 = Vector3()
var _tmp_rotation: Vector3 = Vector3()

func reset_rotation(rot: Vector3) -> void:
    rotation = rot
    _rotation = rot
    _tmp_rotation = rot

func _ready() -> void:
    reset_rotation(rotation)

    @warning_ignore(return_value_discarded)
    control.connect("gui_input", gui_input)

func gui_input(event: InputEvent):
    if not current:
        return

    if captured:
        if event is InputEventMouseMotion:
            var dt = sensitivity / 1500
            
            if OS.has_feature("wasm"):
                dt /= 6
            
            _rotation.y -= event.relative.x * dt
            _rotation.x -= event.relative.y * dt
            if restric:
                _rotation.x = clamp(_rotation.x, PI/-2, PI/2)

    if event is InputEventMouseButton:
        match event.button_index:
            MOUSE_BUTTON_LEFT:
                if event.pressed:
                    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
                    captured = true
                    captured_position = event.position
                else:
                    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
                    captured = false
                    control.warp_mouse(captured_position)

            MOUSE_BUTTON_WHEEL_UP: # increase fly velocity
                max_speed *= speed_scale
            MOUSE_BUTTON_WHEEL_DOWN: # decrease fly velocity
                max_speed /= speed_scale

func set_rotation(rot: Vector3):
    rotation = rot

func _process(delta: float) -> void:
    var direction = Vector3(
            float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
            float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q)), 
            float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
        ).normalized()


    if captured and direction.length() != 0:
        _velocity += (max_speed - _velocity) * delta * acceleration * sensitivity
        _translate = direction * _velocity * delta
    else:
        _velocity = min_speed;
        _translate -= _translate * clamp(delta * smooth, 0, 1);

    translate(_translate)

    var _rotate := (_rotation - _tmp_rotation) * (clamp(delta * smooth * 1.5, 0.01, 1.0) as float)
    _tmp_rotation += _rotate
    set_rotation(_tmp_rotation)

    const dd := 0.00000001
    moving = _rotate.length_squared() > dd || _translate.length_squared() > dd
    
���(�t:�RSCC      �  �  (�/�`�� ��A4`U�0h�3X   ���6y���6�	!ro9"��KŅ�'���cS�F��1 / 5 ����[i�|�ɸ�Ɛm��+�[�C�b�� +����p�⌅����|�N���f������Y*��K����?x��-�����5ܔ����7I�X���L�M}P��;%�;޴�)5+��E�\���H��en�S��F�pF��"��=����a"Q�����x����/�$Z��.��BNO�6�VK54��Trp����)YT�м? p�4t;��h���l� �����EnZ�(���f�#���V���M��Cch3h�
��λ�E��Al�ϗ�+Z���6 ���:��`��#���Q0��@�f�@W`�`t8�頰�V=�깼��4?�w- ��RSCC��@tool

extends Control


@onready var camera: FreeCamera3D = %FreeCamera3D
var initCameraTransform: Transform3D
var initCameraRotation: Vector3

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    initCameraTransform = camera.transform
    initCameraRotation = camera.rotation
    
    %camera_aperture_s.value = %always_uniform_camera.aperture
    %camera_fov_s.value = camera.fov
    %camera_focus_s.value = %always_uniform_camera.focus
    %gamma_s.value = %always_uniform_camera.gamma
    %max_sample_s.value = %OutShaderRect.max_sample


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    %fps.text = str(Performance.get_monitor(Performance.TIME_FPS))
    %sample.text = str(%OutShaderRect.frame)
    if is_instance_valid(camera):
        %camera_speed.text = str(camera.max_speed)
        %camera_speed_s.value = camera.max_speed


func _on_sampleonceb_pressed() -> void:
    %OutShaderRect.frame = 0


func _on_restcamerab_pressed() -> void:
    camera.transform = initCameraTransform
    camera.reset_rotation(initCameraRotation)
    %OutShaderRect.frame = 0


func _on_camera_speed_s_value_changed(value: float) -> void:
    camera.max_speed = value


func _on_camera_aperture_s_value_changed(value: float) -> void:
    %always_uniform_camera.aperture = value
    %camera_aperture.text = str(value)
    %OutShaderRect.frame = 0


func _on_camera_focus_s_value_changed(value: float) -> void:
    %always_uniform_camera.focus = value
    %camera_focus.text = str(value)
    %OutShaderRect.frame = 0


func _on_camera_fov_s_value_changed(value: float) -> void:
    camera.fov = value
    %camera_fov.text = str(value)
    %OutShaderRect.frame = 0


func _on_gamma_s_value_changed(value: float) -> void:
    %always_uniform_camera.gamma = value
    %gamma.text = str(value)
    %OutShaderRect.frame = 0


func _on_max_sample_s_value_changed(value: float) -> void:
    %OutShaderRect.max_sample = int(value)
    %max_sample.text = str(value)
W[-{`���:^�YRSRC                     PackedScene            ��������                                                  Control    RayTracing    SubViewport    resource_local_to_scene    resource_name    shader !   shader_parameter/camera_aperture    shader_parameter/camera_aspect    shader_parameter/camera_focus    shader_parameter/camera_gamma !   shader_parameter/camera_position !   shader_parameter/camera_rotation    shader_parameter/camera_vfov    script    shader_parameter/frame    viewport_path    script/source 	   _bundled       Script &   res://addons/RayTracing/main_panel.gd ��������   Shader 8   res://addons/RayTracing/shaders/raytracing_pbr.gdshader ��������   Script F   res://addons/RayTracing/shared/script/always/always_uniform_camera.gd ��������   Script E   res://addons/RayTracing/shared/script/always/alwasy_fill_viewport.gd ��������   Shader 9   res://addons/RayTracing/shaders/post_processing.gdshader ��������   Script 6   res://addons/RayTracing/shared/script/FreeCamera3D.gd ��������	   StyleBox 9   res://addons/RayTracing/theme/ui_style_box_flat.stylebox ;"w�k��4      local://ShaderMaterial_3d0nr          local://ShaderMaterial_mfx53 �         local://ViewportTexture_c50hr          local://GDScript_5caek I         local://PackedScene_ot210 �         ShaderMaterial 	                  )   {�G�zt?   )   !%̴��?         @	   )   ffffff�?
      ǝ��LTQ@��>      �L�UOV?;	�    z�	?��W?�\~?�1�=�w�        �A         ShaderMaterial                        qC         ViewportTexture                             	   GDScript          q  @tool

extends TextureRect

@onready var camera: FreeCamera3D = %FreeCamera3D
@onready var viewport: SubViewport = $".."

var frame: float = 0
var max_sample: float = 1024

func _ready() -> void:
    viewport.size_changed.connect(on_resize)
    resized.connect(on_resize)
    
func on_resize():
        frame = -1

func _process(_delta: float) -> void:
    if frame >= max_sample:
        frame = 0
    if is_instance_valid(camera):
        if camera.moving:
            frame = 0
            
    if Input.is_action_pressed("ui_accept"):
        frame = 0

    frame += 1

    material.set_shader_parameter("frame", frame)
    PackedScene          	         names "   o   
   MainPanel    layout_mode    anchors_preset    anchor_right    anchor_bottom    grow_horizontal    grow_vertical    size_flags_horizontal    size_flags_vertical    focus_mode    script    Control    unique_name_in_owner    mouse_filter    mouse_default_cursor_shape    RayTracing    texture_filter    stretch    stretch_shrink    SubViewportContainer    SubViewport    disable_3d    transparent_bg    handle_input_locally    size    render_target_clear_mode    render_target_update_mode    ShaderRect 	   material    offset_right    offset_bottom    metadata/_edit_use_anchors_ 
   ColorRect    always_uniform_camera    Node    alwasy_fill_viewport    UseBackBuffer    OutShaderRect    texture    TextureRect    FreeCamera3D 
   transform    rotation_edit_mode    current    fov    sensitivity 	   velocity 
   max_speed    smooth 	   Camera3D    UI    MarginContainer %   theme_override_constants/margin_left $   theme_override_constants/margin_top &   theme_override_constants/margin_right '   theme_override_constants/margin_bottom    PanelContainer    offset_left    offset_top    theme_override_styles/panel    VBoxContainer    HBoxContainer    Label    text    max_sample    horizontal_alignment    HBoxContainer2    max_sample_s 
   min_value 
   max_value    value 	   exp_edit    HSlider    HBoxContainer3    gamma    HBoxContainer4    gamma_s    step    HBoxContainer7    camera_fov    HBoxContainer8    camera_fov_s    HBoxContainer9    camera_focus    HBoxContainer10    camera_focus_s    HBoxContainer11    camera_aperture    HBoxContainer12    camera_aperture_s    HBoxContainer5    camera_speed    HBoxContainer6    camera_speed_s    rest_camera_b    Button    sample_once_b    MarginContainer2    anchor_left    fps    sample    _on_max_sample_s_value_changed    value_changed    _on_gamma_s_value_changed    _on_camera_fov_s_value_changed !   _on_camera_focus_s_value_changed $   _on_camera_aperture_s_value_changed !   _on_camera_speed_s_value_changed    _on_restcamerab_pressed    pressed    _on_sampleonceb_pressed    	   variants    y                    �?                                         -   �  �                        �C     HC                                                  �?              �?              �?          �@     �A              @@     �@     zD      A     �C     �C           �C     �C              �C           �A     �C     �C     �C     �A     �B      Max Samples      �B      1024      8B     �A     �G     �D     HB     �B     tB      Gamma      �B      0.5      �B     �B)   ����MbP?)   {�G�z�?      ?     �B     �B      B      FOV      B      30      C     C     4C     C     0C     4B      Focus      DB      2      DC    @F      @     bC     �B   	   Aperture      �B      0.005      fC     vC)   {�G�zt?     zC     �C     �B      Camera Speed      �B      1000      �C     �C)   �������?     �C    ��C      Reset Position     ��C     �C   	   Resample      |�     BC            ^C     $C     @C     C     (C     �B     C     �A      FPS       60      `B     �B   	   Sampling       863      pB     �B      verion      XB      HK-SHAO       node_count    >         nodes     ^  ��������       ����
                                                      	      
                        ����
                                              	                                   ����                                                                     ����                        	            
                     ����
                                               	                             "   !   ����         
                 "   #   ����   
                    $   ����                                                                     ����                        	            
              '   %   ����                                               	            &      
                	       "   #   ����   
                  1   (   ����
         )      *      +      ,      
      -      .      /      0                     2   ����                                                         3   3   ����                     4      5      6      7                 8   8   ����   9      :                  ;                 3   3   ����                4   !   5   !   6   !   7   !              <   <   ����   9   "   :   "      #      $              =   =   ����      %      &              >   >   ����      '      &   ?   (              >   @   ����         9   )      %      &          ?   *   A                 =   B   ����   :         %      +              H   C   ����
            %      ,                      D      E   -   F   .   G                 =   I   ����   :   /      %      0              >   >   ����      1      &   ?   2              >   J   ����         9   3      %      &          ?   4   A                 =   K   ����   :   5      %      6              H   L   ����            %      ,                      D   7   E      M   8   F   9   G                 =   N   ����   :   :      %      ;              >   >   ����      <      &   ?   =              >   O   ����         9   >      %      &          ?   ?   A                 =   P   ����   :   @      %      A              H   Q   ����	            %      ,                      E   B   M   7   F                 =   R   ����   :   C      %      D               >   >   ����      E      &   ?   F               >   S   ����         9   G      %      &          ?   H   A                 =   T   ����   :   B      %      I       #       H   U   ����            %      ,                      D   7   E   J   M   7   F   K   G                 =   V   ����   :         %      L       %       >   >   ����      M      &   ?   N       %       >   W   ����         9   O      %      &          ?   P   A                 =   X   ����   :   Q      %      R       (       H   Y   ����	            %      ,                      E      M   7   F   S              =   Z   ����   :   T      %      U       *       >   >   ����      V      &   ?   W       *       >   [   ����         9   X      %      &          ?   Y   A                 =   \   ����   :   Z      %      [       -       H   ]   ����	            %      ,                      E   J   M   \   F                 _   ^   ����         :   ]      %      ^         ?   _              _   `   ����         :   `      %      a         ?   b              3   a   ����         b            9   c      d      e         4      5      6      7          1       8   8   ����   9      :         f      g   ;          2       3   3   ����      h      i   4   !   5   !   6   !   7   !       3       <   <   ����   9   "   :   "      j      k       4       =   =   ����      l      &       5       >   >   ����      m      &   ?   n       5       >   c   ����         9   <      l      &          ?   o   A          4       =   B   ����   :         l      p       8       >   >   ����      q      &   ?   r       8       >   d   ����         9   0      l      &          ?   s   A          4       =   I   ����   :   t      l      u       ;       >   >   ����      /      &   ?   v       ;       >   d   ����   9   w      l      &          ?   x   A                conn_count             conns     0          f   e                 f   g                 f   h          $       f   i          )       f   j          .       f   k          /       m   l          0       m   n                node_paths              editable_instances              version             RSRC#o���@tool
extends EditorPlugin

const MainPanel = preload("res://addons/RayTracing/main_panel.tscn")

var main_panel_instance: Control

func _enter_tree() -> void:
    main_panel_instance = MainPanel.instantiate()
    
    # Add the main panel to the editor's main viewport.
    var ei := get_editor_interface()
    var ms := ei.get_editor_main_screen()
    ms.add_child(main_panel_instance)
    
    # Hide the main panel. Very much required.
    _make_visible(false)


func _exit_tree() -> void:
    if is_instance_valid(main_panel_instance):
        main_panel_instance.queue_free()

func _has_main_screen():
    return true


func _make_visible(visible):
    if is_instance_valid(main_panel_instance):
        main_panel_instance.visible = visible
        if visible:
            main_panel_instance.process_mode = Node.PROCESS_MODE_INHERIT
        else:
            main_panel_instance.process_mode = Node.PROCESS_MODE_DISABLED


func _get_plugin_name():
    return "RayTracing"


func _get_plugin_icon():
    return get_editor_interface().get_base_control().get_theme_icon("3D", "EditorIcons")

>����R�RSRC                     PackedScene            ��������                                                  ..    Node3D    FreeCamera3D    RayTracing    SubViewport    BackBuffer    resource_local_to_scene    resource_name    shader #   shader_parameter/camera_focus_dist    shader_parameter/camera_fov $   shader_parameter/camera_lens_radius !   shader_parameter/camera_position !   shader_parameter/camera_rotation    script    shader_parameter/frame    viewport_path 	   _bundled       Shader .   res://test/shaders/camera_raytracing.gdshader ��������   Script 6   res://test/scripts/always/always_shader_camera_pos.gd ��������   Shader ,   res://test/shaders/test_backbuffer.gdshader ��������   Script I   res://addons/RayTracing/shared/script/always/always_shader_backbuffer.gd ��������   Shader '   res://test/shaders/test_gamma.gdshader ��������   Script &   res://test/scripts/OldFreeCamera3D.gd ��������      local://ShaderMaterial_jl6vl �         local://ShaderMaterial_bl27b          local://ViewportTexture_nggje ?         local://ShaderMaterial_o3f6h s         local://ViewportTexture_dafq8 �         local://PackedScene_qyuub �         ShaderMaterial                 	         A
        HB   )   {�G�z�?                     ShaderMaterial                               ViewportTexture                            ShaderMaterial                         ViewportTexture                            PackedScene          	         names "   '      Control    layout_mode    anchors_preset    anchor_right    anchor_bottom    grow_horizontal    grow_vertical 
   BlackBack    visible    color 
   ColorRect 
   WhiteBack    RayTracing    stretch    stretch_shrink    SubViewportContainer    SubViewport    disable_3d    handle_input_locally    size    render_target_clear_mode    render_target_update_mode 	   material    size_flags_horizontal    size_flags_vertical    always_shader_camera_pos    script    camera    Node    BackBuffer    TextureRect    texture    always_shader_backbuffer    Gamma    Node3D    FreeCamera3D    unique_name_in_owner 
   transform 	   Camera3D    	   variants                        �?                              �?   ��-?��,?��:?  �?      -   X  ,                                                                                                                     �?            �pr?�l�>    �l���pr?    �!@�?@               node_count             nodes       ��������        ����                                                    
      ����                                       	                  
      ����                                       	                        ����                                                              ����                        	      
              
   
   ����                                                                    ����           @                     ����                                                              ����                        	      
                    ����                                                 	              ����                        !   ����                                                              ����                        
                    ����                                                         "   "   ����               &   #   ����   $      %                      conn_count              conns               node_paths              editable_instances              version             RSRCC���٪�extends Node

@export var camera: FreeCamera3D

var material: ShaderMaterial
var textureRect: TextureRect

var image: Image

var frame: float = 0


func _ready() -> void:
	textureRect = get_parent()
	material = textureRect.material


func _process(_delta: float) -> void:
	if is_instance_valid(camera):
		if camera.moving:
			frame = 0
	if Input.is_action_pressed("ui_accept"):
		frame = 0

	frame += 1

	material.set_shader_parameter(
		"frame", frame)
_���v��+hextends Node

@export var camera: Camera3D

var material: ShaderMaterial


func _ready() -> void:
    material = get_parent().material


func _process(_delta: float) -> void:

    var camera_position := camera.transform.origin
    var camera_rotation := camera.transform.basis

    material.set_shader_parameter(
        "camera_position", camera_position)

    material.set_shader_parameter(
        "camera_rotation", camera_rotation)
����P���*class_name OldFreeCamera3D

extends Camera3D

@export_range(0, 10, 0.01) var sensitivity:float = 3
@export_range(0, 1000, 0.1) var velocity:float = 5
@export_range(0, 1, 0.0001) var acceleration:float = 0.01
@export_range(0, 10, 0.01) var speed_scale:float = 1.17
@export var max_speed:float = 1000
@export var min_speed:float = 0.0
@export_range(0, 100, 0.01) var smooth:float = 10
@export var restric: bool = true

var moving: bool = false

var _velocity: float = 0.0;
var _translate: Vector3 = Vector3()
var _rotation: Vector3 = Vector3()
var _tmp_rotation: Vector3 = Vector3()


func _ready() -> void:
    _rotation = rotation
    _tmp_rotation = rotation

func _input(event: InputEvent):
    if not current:
        return

    if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
        if event is InputEventMouseMotion:
            _rotation.y -= event.relative.x / 1000 * sensitivity
            _rotation.x -= event.relative.y / 1000 * sensitivity
            if restric:
                _rotation.x = clamp(_rotation.x, PI/-2, PI/2)

    if event is InputEventMouseButton:
        match event.button_index:
            MOUSE_BUTTON_LEFT:
                if event.pressed:
                    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
                else:
                    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

            MOUSE_BUTTON_WHEEL_UP: # increase fly velocity
                max_speed *= speed_scale
            MOUSE_BUTTON_WHEEL_DOWN: # decrease fly velocity
                max_speed /= speed_scale

func set_rotation(rot: Vector3):
    rotation = rot

func _process(delta: float) -> void:
    var direction = Vector3(
            float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
            float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q)), 
            float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    ).normalized()


    if direction.length() != 0:
        _velocity += (max_speed - _velocity) * delta * acceleration * sensitivity
        _translate = direction * _velocity * delta
    else:
        _velocity = min_speed;
        _translate -= _translate * clamp(delta * smooth, 0, 1);

    translate(_translate)

    var _rotate := (_rotation - _tmp_rotation) * (clamp(delta * smooth * 1.5, 0.01, 1.0) as float)
    _tmp_rotation += _rotate
    set_rotation(_tmp_rotation)

    var dd := 0.00000001
    moving = _rotate.length_squared() > dd || _translate.length_squared() > dd
X͑�,`shader_type canvas_item;

uniform vec3 camera_position = vec3(0.0, 0.0, 4.0); // 传入摄像机的位置
uniform mat3 camera_rotation = mat3(1);             // 摄像机的旋转

uniform float camera_fov = 50.;
uniform float camera_lens_radius = 0.1;
uniform float camera_focus_dist = 10.;

// Raytracing in one weekend, chapter 12: Where next? Created by Reinder Nijhoff 2018
// @reindernijhoff
//
// https://www.shadertoy.com/view/XlycWh
//
// These shaders are my implementation of the raytracer described in the (excellent) 
// book "Raytracing in one weekend" [1] by Peter Shirley (@Peter_shirley). I have tried 
// to follow the code from his book as much as possible.
//
// [1] http://in1weekend.blogspot.com/2016/01/ray-tracing-in-one-weekend.html
//

#define MAX_FLOAT 1e10
#define MAX_RECURSION 12

#define LAMBERTIAN 0
#define METAL 1
#define DIELECTRIC 2

//
// Hash functions by Nimitz:
// https://www.shadertoy.com/view/Xt3cDn
//

uint base_hash(uvec2 p) {
    p = 1103515245U*((p >> 1U)^(p.yx));
    uint h32 = 1103515245U*((p.x)^(p.y>>3U));
    return h32 ^ (h32 >> 16U);
}

float hash1(inout float seed) {
    uint n = base_hash(floatBitsToUint(vec2(seed+=.1,seed+=.1)));
    return float(n)/intBitsToFloat(-1);
}

vec2 hash2(inout float seed) {
    uint n = base_hash(floatBitsToUint(vec2(seed+=.1,seed+=.1)));
    uvec2 rz = uvec2(n, n*48271U);
    return vec2(rz.xy & uvec2(0x7fffffff))/float(0x7fffffff);
}

vec3 hash3(inout float seed) {
    uint n = base_hash(floatBitsToUint(vec2(seed+=.1,seed+=.1)));
    uvec3 rz = uvec3(n, n*16807U, n*48271U);
    return vec3(rz & uvec3(0x7fffffff))/float(0x7fffffff);
}

//
// Ray trace helper functions
//

float schlick(float cosine, float ior) {
    float r0 = (1.-ior)/(1.+ior);
    r0 = r0*r0;
    return r0 + (1.-r0)*pow((1.-cosine),5.);
}

bool modified_refract(const in vec3 v, const in vec3 n, const in float ni_over_nt, 
                      out vec3 refracted) {
    float dt = dot(v, n);
    float discriminant = 1. - ni_over_nt*ni_over_nt*(1.-dt*dt);
    if (discriminant > 0.) {
        refracted = ni_over_nt*(v - n*dt) - n*sqrt(discriminant);
        return true;
    } else { 
        return false;
    }
}

vec3 random_in_unit_sphere(in float seed) {
    vec3 h = hash3(seed) * vec3(2.,6.28318530718,1.)-vec3(1,0,0);
    float phi = h.y;
    float r = pow(h.z, 1./3.);
	return r * vec3(sqrt(1.-h.x*h.x)*vec2(sin(phi),cos(phi)),h.x);
}

vec2 random_in_unit_disk(inout float seed) {
    vec2 h = hash2(seed) * vec2(1.,6.28318530718);
    float phi = h.y;
    float r = sqrt(h.x);
	return r * vec2(sin(phi),cos(phi));
}

//
// Ray
//

struct ray {
    vec3 origin, direction;
};

//
// Material
//

struct material {
    int type;
    vec3 albedo;
    float v;
};

//
// Hit record
//

struct hit_record {
    float t;
    vec3 p, normal;
    material mat;
};

bool material_scatter(const in ray r_in, const in hit_record rec, out vec3 attenuation, 
                      out ray scattered, float g_seed) {
	switch (rec.mat.type) {
		case LAMBERTIAN: 
			vec3 rd = normalize(rec.normal + random_in_unit_sphere(g_seed));
	        scattered = ray(rec.p, rd);
	        attenuation = rec.mat.albedo;
	        return true;
		case METAL: 
			vec3 rd = reflect(r_in.direction, rec.normal);
	        scattered = ray(rec.p, normalize(rd + rec.mat.v*random_in_unit_sphere(g_seed)));
	        attenuation = rec.mat.albedo;
	        return true;
		case DIELECTRIC: 
	        vec3 outward_normal, refracted, 
	             reflected = reflect(r_in.direction, rec.normal);
	        float ni_over_nt, reflect_prob, cosine;
	        
	        attenuation = vec3(1);
	        if (dot(r_in.direction, rec.normal) > 0.) {
	            outward_normal = -rec.normal;
	            ni_over_nt = rec.mat.v;
	            cosine = dot(r_in.direction, rec.normal);
	            cosine = sqrt(1. - rec.mat.v*rec.mat.v*(1.-cosine*cosine));
	        } else {
	            outward_normal = rec.normal;
	            ni_over_nt = 1. / rec.mat.v;
	            cosine = -dot(r_in.direction, rec.normal);
	        }
	        
	        if (modified_refract(r_in.direction, outward_normal, ni_over_nt, refracted)) {
		        reflect_prob = schlick(cosine, rec.mat.v);
	        } else {
	            reflect_prob = 1.;
	        }
	        
	        if (hash1(g_seed) < reflect_prob) {
	            scattered = ray(rec.p, reflected);
	        } else {
	            scattered = ray(rec.p, refracted);
	        }
	        return true;
		default:
			return false;
	}
}

//
// Hitable, for now this is always a sphere
//

struct hitable {
    vec3 center;
    float radius;
};

bool hitable_hit(const in hitable hb, const in ray r, const in float t_min, 
                 const in float t_max, inout hit_record rec) {
    // always a sphere
    vec3 oc = r.origin - hb.center;
    float b = dot(oc, r.direction);
    float c = dot(oc, oc) - hb.radius * hb.radius;
    float discriminant = b * b - c;
    if (discriminant < 0.0) return false;

	float s = sqrt(discriminant);
	float t1 = -b - s;
	float t2 = -b + s;
	
	float t = t1 < t_min ? t2 : t1;
    if (t < t_max && t > t_min) {
        rec.t = t;
        rec.p = r.origin + t*r.direction;
        rec.normal = (rec.p - hb.center) / hb.radius;
	    return true;
    } else {
        return false;
    }
}

//
// Color & Scene
//

bool world_hit(const in ray r, const in float t_min, 
               const in float t_max, out hit_record rec) {
    rec.t = t_max;
    bool hit = false;

  	if (hitable_hit(hitable(vec3(0,-1000,-1),1000.),r,t_min,rec.t,rec)) {
		hit=true;rec.mat=material(LAMBERTIAN,vec3(.5),0.);
	}

  	if (hitable_hit(hitable(vec3( 0,1,0),1.),r,t_min,rec.t,rec)) {
		hit=true;rec.mat=material(DIELECTRIC,vec3(0),1.5);
	}
    if (hitable_hit(hitable(vec3(-4,1,0),1.),r,t_min,rec.t,rec)) {
		hit=true;rec.mat=material(LAMBERTIAN,vec3(.4,.2,.1),0.);
	}
	if (hitable_hit(hitable(vec3( 4,1,0),1.),r,t_min,rec.t,rec)) {
		hit=true;rec.mat=material(METAL     ,vec3(.7,.6,.5),0.);
	}
    
    for (int a = -3; a < 3; a++) {
        for (int b = -3; b < 3; b++) {
            float m_seed = float(a) + float(b)/1000.;
            vec3 rand1 = hash3(m_seed);            
            vec3 center = vec3(float(a)+.9*rand1.x,.2,float(b)+.9*rand1.y); 
            float choose_mat = rand1.z;
            
            if (distance(center,vec3(0,1,0)) > 1.1) {
                if (choose_mat < .8) { // diffuse
                    if (hitable_hit(hitable(center,.2),r,t_min,rec.t,rec)) {
                        hit=true;
						rec.mat=material(LAMBERTIAN, hash3(m_seed)* hash3(m_seed),0.);
                    }
                } else if (choose_mat < 0.95) { // metal
                    if (hitable_hit(hitable(center,.2),r,t_min,rec.t,rec)) {
                        hit=true;
						rec.mat=material(METAL, vec3(.7,.6,.5),0.);
                    }
                } else { // glass
                    if (hitable_hit(hitable(center,.2),r,t_min,rec.t,rec)) {
                        hit=true;
						rec.mat=material(DIELECTRIC, vec3(0),1.5);
                    }
                }
            }
        }
    }
    
    return hit;
}

vec3 color(in ray r, float g_seed) {
    vec3 col = vec3(1);  
	hit_record rec;
    
    for (int i=0; i<MAX_RECURSION; i++) {
    	if (world_hit(r, 0.001, MAX_FLOAT, rec)) {
            ray scattered;
            vec3 attenuation;
            if (material_scatter(r, rec, attenuation, scattered, g_seed)) {
                col *= attenuation;
                r = scattered;
            } else {
                return vec3(0);
            }
	    } else {
            float t = .5*r.direction.y + .5;
            col *= mix(vec3(1),vec3(.5,.7,1), t);
            return col;
    	}
    }
    return vec3(0);
}

//
// Camera
//

struct camera {
    vec3 origin, lower_left_corner, horizontal, vertical, u, v, w;
    float lens_radius;
};

camera camera_const(const in vec3 lookfrom, const in vec3 lookat, const in vec3 vup, 
                    const in float vfov, const in float aspect, const in float aperture, 
                    const in float focus_dist) {
    camera cam;    
    cam.lens_radius = aperture / 2.;
    float theta = vfov*3.14159265359/180.;
    float half_height = tan(theta/2.);
    float half_width = aspect * half_height;
    cam.origin = lookfrom;
    cam.w = normalize(lookfrom - lookat);
    cam.u = normalize(cross(vup, cam.w));
    cam.v = cross(cam.w, cam.u);
    cam.lower_left_corner = cam.origin  - half_width*focus_dist*cam.u -half_height*focus_dist*cam.v - focus_dist*cam.w;
    cam.horizontal = 2.*half_width*focus_dist*cam.u;
    cam.vertical = 2.*half_height*focus_dist*cam.v;
    return cam;
}
    
ray camera_get_ray(camera c, vec2 uv, float g_seed) {
    vec2 rd = c.lens_radius*random_in_unit_disk(g_seed);
    vec3 offset = c.u * rd.x + c.v * rd.y;
    return ray(c.origin + offset, 
               normalize(c.lower_left_corner + uv.x*c.horizontal + uv.y*c.vertical - c.origin - offset));
}

//
// Main
//


void fragment() {
	vec2 fragCoord = FRAGCOORD.xy;
	vec2 resolution = 1. / SCREEN_PIXEL_SIZE.xy;
	
	float g_seed = TIME + float(base_hash(floatBitsToUint(fragCoord)))/float(0xffffffff);
	
	// camera
	float lens_radius = camera_lens_radius;
	float fov = camera_fov;
	float focus_dist = camera_focus_dist;
	
	vec3 ro = camera_position;
	mat3 ca = camera_rotation;

	vec3 lookfrom = ro;
	vec3 lookat = ro + ca * vec3(0., 0., -1.);
	
	float aspect = resolution.x/resolution.y;
	camera cam = camera_const(lookfrom,
		lookat, vec3(0,-1,0), fov, aspect, lens_radius, focus_dist);
	
	vec2 uv = (fragCoord + hash2(g_seed))/resolution.xy;
	uv.x = 1. - uv.x;
	
	ray r = camera_get_ray(cam, uv, g_seed);
	vec3 col = color(r, g_seed);
	
//	const float N = 100.;
//	for (float i = 1.111; i < N; i++){
//		g_seed += 10.0*i + sin(i);
//		uv = (fragCoord + hash2(g_seed))/resolution.xy;
//		uv.x = 1. - uv.x;
//		r = camera_get_ray(cam, uv, g_seed);
//		col += color(r, g_seed);
//	}
//	col = col / N;

	vec4 tot = vec4(0.0);

	tot = vec4(col, 1.0);
	
	COLOR = tot;
}���p�"-;�Υ���shader_type canvas_item;

uniform float frame = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec4 back = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	COLOR = mix(back, color, 1.0 / frame);
}
_�F�Nshader_type canvas_item;

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR = vec4(sqrt(COLOR.rgb), 1.0);
}
�rF��_oOk��eGST2   �   �      ����               � �        &  RIFF  WEBPVP8L  /������!"2�H�l�m�l�H�Q/H^��޷������d��g�(9�$E�Z��ߓ���'3���ض�U�j��$�՜ʝI۶c��3� [���5v�ɶ�=�Ԯ�m���mG�����j�m�m�_�XV����r*snZ'eS�����]n�w�Z:G9�>B�m�It��R#�^�6��($Ɓm+q�h��6�4mb�h3O���$E�s����A*DV�:#�)��)�X/�x�>@\�0|�q��m֋�d�0ψ�t�!&����P2Z�z��QF+9ʿ�d0��VɬF�F� ���A�����j4BUHp�AI�r��ِ���27ݵ<�=g��9�1�e"e�{�(�(m�`Ec\]�%��nkFC��d���7<�
V�Lĩ>���Qo�<`�M�$x���jD�BfY3�37�W��%�ݠ�5�Au����WpeU+.v�mj��%' ��ħp�6S�� q��M�׌F�n��w�$$�VI��o�l��m)��Du!SZ��V@9ד]��b=�P3�D��bSU�9�B���zQmY�M~�M<��Er�8��F)�?@`�:7�=��1I]�������3�٭!'��Jn�GS���0&��;�bE�
�
5[I��=i�/��%�̘@�YYL���J�kKvX���S���	�ڊW_�溶�R���S��I��`��?֩�Z�T^]1��VsU#f���i��1�Ivh!9+�VZ�Mr�טP�~|"/���IK
g`��MK�����|CҴ�ZQs���fvƄ0e�NN�F-���FNG)��W�2�JN	��������ܕ����2
�~�y#cB���1�YϮ�h�9����m������v��`g����]1�)�F�^^]Rץ�f��Tk� s�SP�7L�_Y�x�ŤiC�X]��r�>e:	{Sm�ĒT��ubN����k�Yb�;��Eߝ�m�Us�q��1�(\�����Ӈ�b(�7�"�Yme�WY!-)�L���L�6ie��@�Z3D\?��\W�c"e���4��AǘH���L�`L�M��G$𩫅�W���FY�gL$NI�'������I]�r��ܜ��`W<ߛe6ߛ�I>v���W�!a��������M3���IV��]�yhBҴFlr�!8Մ�^Ҷ�㒸5����I#�I�ڦ���P2R���(�r�a߰z����G~����w�=C�2������C��{�hWl%��и���O������;0*��`��U��R��vw�� (7�T#�Ƨ�o7�
�xk͍\dq3a��	x p�ȥ�3>Wc�� �	��7�kI��9F}�ID
�B���
��v<�vjQ�:a�J�5L&�F�{l��Rh����I��F�鳁P�Nc�w:17��f}u}�Κu@��`� @�������8@`�
�1 ��j#`[�)�8`���vh�p� P���׷�>����"@<�����sv� ����"�Q@,�A��P8��dp{�B��r��X��3��n$�^ ��������^B9��n����0T�m�2�ka9!�2!���]
?p ZA$\S��~B�O ��;��-|��
{�V��:���o��D��D0\R��k����8��!�I�-���-<��/<JhN��W�1���(�#2:E(*�H���{��>��&!��$| �~�+\#��8�> �H??�	E#��VY���t7���> 6�"�&ZJ��p�C_j����	P:�~�G0 �J��$�M���@�Q��Yz��i��~q�1?�c��Bߝϟ�n�*������8j������p���ox���"w���r�yvz U\F8��<E��xz�i���qi����ȴ�ݷ-r`\�6����Y��q^�Lx�9���#���m����-F�F.-�a�;6��lE�Q��)�P�x�:-�_E�4~v��Z�����䷳�:�n��,㛵��m�=wz�Ξ;2-��[k~v��Ӹ_G�%*�i� ����{�%;����m��g�ez.3���{�����Kv���s �fZ!:� 4W��޵D��U��
(t}�]5�ݫ߉�~|z��أ�#%���ѝ܏x�D4�4^_�1�g���<��!����t�oV�lm�s(EK͕��K�����n���Ӌ���&�̝M�&rs�0��q��Z��GUo�]'G�X�E����;����=Ɲ�f��_0�ߝfw�!E����A[;���ڕ�^�W"���s5֚?�=�+9@��j������b���VZ^�ltp��f+����Z�6��j�`�L��Za�I��N�0W���Z����:g��WWjs�#�Y��"�k5m�_���sh\���F%p䬵�6������\h2lNs�V��#�t�� }�K���Kvzs�>9>�l�+�>��^�n����~Ěg���e~%�w6ɓ������y��h�DC���b�KG-�d��__'0�{�7����&��yFD�2j~�����ټ�_��0�#��y�9��P�?���������f�fj6͙��r�V�K�{[ͮ�;4)O/��az{�<><__����G����[�0���v��G?e��������:���١I���z�M�Wۋ�x���������u�/��]1=��s��E&�q�l�-P3�{�vI�}��f��}�~��r�r�k�8�{���υ����O�֌ӹ�/�>�}�t	��|���Úq&���ݟW����ᓟwk�9���c̊l��Ui�̸z��f��i���_�j�S-|��w�J�<LծT��-9�����I�®�6 *3��y�[�.Ԗ�K��J���<�ݿ��-t�J���E�63���1R��}Ғbꨝט�l?�#���ӴQ��.�S���U
v�&�3�&O���0�9-�O�kK��V_gn��k��U_k˂�4�9�v�I�:;�w&��Q�ҍ�
��fG��B��-����ÇpNk�sZM�s���*��g8��-���V`b����H���
3cU'0hR
�w�XŁ�K݊�MV]�} o�w�tJJ���$꜁x$��l$>�F�EF�޺�G�j�#�G�t�bjj�F�б��q:�`O�4�y�8`Av<�x`��&I[��'A�˚�5��KAn��jx ��=Kn@��t����)�9��=�ݷ�tI��d\�M�j�B�${��G����VX�V6��f�#��V�wk ��W�8�	����lCDZ���ϖ@���X��x�W�Utq�ii�D($�X��Z'8Ay@�s�<�x͡�PU"rB�Q�_�Q6  �[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://ct1wv1paqrpy4"
path="res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex"
metadata={
"vram_texture": false
}

[deps]

source_file="res://icon.svg"
dest_files=["res://.godot/imported/icon.svg-218a8f2b3041327d8a5756f3a245f83b.ctex"]

[params]

compress/mode=0
compress/lossy_quality=0.7
compress/hdr_compression=1
compress/bptc_ldr=0
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
svg/scale=1.0
editor/scale_with_editor_scale=false
editor/convert_colors_with_editor_theme=false
}:���p��P!�[remap]

path="res://.godot/exported/133200997/export-128d0d3707d7b3a2422f44dcb72e71e4-main_panel.scn"
�B'���.�[remap]

path="res://.godot/exported/133200997/export-a46938bc29a316f6833b00cdec411d91-test_raytracing_scene.scn"
:)�".�G7V��~�<svg height="128" width="128" xmlns="http://www.w3.org/2000/svg"><g transform="translate(32 32)"><path d="m-16-32c-8.86 0-16 7.13-16 15.99v95.98c0 8.86 7.13 15.99 16 15.99h96c8.86 0 16-7.13 16-15.99v-95.98c0-8.85-7.14-15.99-16-15.99z" fill="#363d52"/><path d="m-16-32c-8.86 0-16 7.13-16 15.99v95.98c0 8.86 7.13 15.99 16 15.99h96c8.86 0 16-7.13 16-15.99v-95.98c0-8.85-7.14-15.99-16-15.99zm0 4h96c6.64 0 12 5.35 12 11.99v95.98c0 6.64-5.35 11.99-12 11.99h-96c-6.64 0-12-5.35-12-11.99v-95.98c0-6.64 5.36-11.99 12-11.99z" fill-opacity=".4"/></g><g stroke-width="9.92746" transform="matrix(.10073078 0 0 .10073078 12.425923 2.256365)"><path d="m0 0s-.325 1.994-.515 1.976l-36.182-3.491c-2.879-.278-5.115-2.574-5.317-5.459l-.994-14.247-27.992-1.997-1.904 12.912c-.424 2.872-2.932 5.037-5.835 5.037h-38.188c-2.902 0-5.41-2.165-5.834-5.037l-1.905-12.912-27.992 1.997-.994 14.247c-.202 2.886-2.438 5.182-5.317 5.46l-36.2 3.49c-.187.018-.324-1.978-.511-1.978l-.049-7.83 30.658-4.944 1.004-14.374c.203-2.91 2.551-5.263 5.463-5.472l38.551-2.75c.146-.01.29-.016.434-.016 2.897 0 5.401 2.166 5.825 5.038l1.959 13.286h28.005l1.959-13.286c.423-2.871 2.93-5.037 5.831-5.037.142 0 .284.005.423.015l38.556 2.75c2.911.209 5.26 2.562 5.463 5.472l1.003 14.374 30.645 4.966z" fill="#fff" transform="matrix(4.162611 0 0 -4.162611 919.24059 771.67186)"/><path d="m0 0v-47.514-6.035-5.492c.108-.001.216-.005.323-.015l36.196-3.49c1.896-.183 3.382-1.709 3.514-3.609l1.116-15.978 31.574-2.253 2.175 14.747c.282 1.912 1.922 3.329 3.856 3.329h38.188c1.933 0 3.573-1.417 3.855-3.329l2.175-14.747 31.575 2.253 1.115 15.978c.133 1.9 1.618 3.425 3.514 3.609l36.182 3.49c.107.01.214.014.322.015v4.711l.015.005v54.325c5.09692 6.4164715 9.92323 13.494208 13.621 19.449-5.651 9.62-12.575 18.217-19.976 26.182-6.864-3.455-13.531-7.369-19.828-11.534-3.151 3.132-6.7 5.694-10.186 8.372-3.425 2.751-7.285 4.768-10.946 7.118 1.09 8.117 1.629 16.108 1.846 24.448-9.446 4.754-19.519 7.906-29.708 10.17-4.068-6.837-7.788-14.241-11.028-21.479-3.842.642-7.702.88-11.567.926v.006c-.027 0-.052-.006-.075-.006-.024 0-.049.006-.073.006v-.006c-3.872-.046-7.729-.284-11.572-.926-3.238 7.238-6.956 14.642-11.03 21.479-10.184-2.264-20.258-5.416-29.703-10.17.216-8.34.755-16.331 1.848-24.448-3.668-2.35-7.523-4.367-10.949-7.118-3.481-2.678-7.036-5.24-10.188-8.372-6.297 4.165-12.962 8.079-19.828 11.534-7.401-7.965-14.321-16.562-19.974-26.182 4.4426579-6.973692 9.2079702-13.9828876 13.621-19.449z" fill="#478cbf" transform="matrix(4.162611 0 0 -4.162611 104.69892 525.90697)"/><path d="m0 0-1.121-16.063c-.135-1.936-1.675-3.477-3.611-3.616l-38.555-2.751c-.094-.007-.188-.01-.281-.01-1.916 0-3.569 1.406-3.852 3.33l-2.211 14.994h-31.459l-2.211-14.994c-.297-2.018-2.101-3.469-4.133-3.32l-38.555 2.751c-1.936.139-3.476 1.68-3.611 3.616l-1.121 16.063-32.547 3.138c.015-3.498.06-7.33.06-8.093 0-34.374 43.605-50.896 97.781-51.086h.066.067c54.176.19 97.766 16.712 97.766 51.086 0 .777.047 4.593.063 8.093z" fill="#478cbf" transform="matrix(4.162611 0 0 -4.162611 784.07144 817.24284)"/><path d="m0 0c0-12.052-9.765-21.815-21.813-21.815-12.042 0-21.81 9.763-21.81 21.815 0 12.044 9.768 21.802 21.81 21.802 12.048 0 21.813-9.758 21.813-21.802" fill="#fff" transform="matrix(4.162611 0 0 -4.162611 389.21484 625.67104)"/><path d="m0 0c0-7.994-6.479-14.473-14.479-14.473-7.996 0-14.479 6.479-14.479 14.473s6.483 14.479 14.479 14.479c8 0 14.479-6.485 14.479-14.479" fill="#414042" transform="matrix(4.162611 0 0 -4.162611 367.36686 631.05679)"/><path d="m0 0c-3.878 0-7.021 2.858-7.021 6.381v20.081c0 3.52 3.143 6.381 7.021 6.381s7.028-2.861 7.028-6.381v-20.081c0-3.523-3.15-6.381-7.028-6.381" fill="#fff" transform="matrix(4.162611 0 0 -4.162611 511.99336 724.73954)"/><path d="m0 0c0-12.052 9.765-21.815 21.815-21.815 12.041 0 21.808 9.763 21.808 21.815 0 12.044-9.767 21.802-21.808 21.802-12.05 0-21.815-9.758-21.815-21.802" fill="#fff" transform="matrix(4.162611 0 0 -4.162611 634.78706 625.67104)"/><path d="m0 0c0-7.994 6.477-14.473 14.471-14.473 8.002 0 14.479 6.479 14.479 14.473s-6.477 14.479-14.479 14.479c-7.994 0-14.471-6.485-14.471-14.479" fill="#414042" transform="matrix(4.162611 0 0 -4.162611 656.64056 631.05679)"/></g></svg>
��   ;"w�k��48   res://addons/RayTracing/theme/ui_style_box_flat.stylebox��Y腄'   res://addons/RayTracing/main_panel.tscn�����1>,   res://test/scenes/test_raytracing_scene.tscn�C�9}��U   res://icon.svg�$�ECFG      _global_script_classesd                    class         FreeCamera3D      language      GDScript      path   5   res://addons/RayTracing/shared/script/FreeCamera3D.gd         base      Camera3D            class         OldFreeCamera3D       language      GDScript      path   %   res://test/scripts/OldFreeCamera3D.gd         base      Camera3D   _global_script_class_iconsD               FreeCamera3D             OldFreeCamera3D           application/config/name          Ray-Tracing-Shader-Demo    application/config/description,      #   Ray Tracing Shader Demo by HK-SHAO.    application/run/main_scene0      '   res://addons/RayTracing/main_panel.tscn    application/config/features$   "         4.0    Forward Plus       application/config/icon         res://icon.svg  "   display/window/size/viewport_width      �  #   display/window/size/viewport_height      X     editor_plugins/enabled0   "      #   res://addons/RayTracing/plugin.cfg  9   rendering/textures/canvas_textures/default_texture_filter          �