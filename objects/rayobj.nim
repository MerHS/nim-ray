import basic3d
import colors
import math
import algorithm

const BOUND_MAX* = 10
const INTENSITY_MIN* = 0.0001

type 
  Col* = tuple[r:float, g:float, b:float]
  Vec* = TVector3d
  BoundBox* = tuple[o:Vec, u:Vec, v:Vec, n:Vec]
  Polygon* = tuple[ai:uint, bi:uint, ci:uint, ani:uint, bni:uint, cni:uint]
  CollPoint = tuple[t:float, norm: Vec]

type Ray* = ref object of RootObj
  center*: Vec
  way*: Vec
  refrac_n*: float # current refraction index
  bound_no*: int

type Screen* = ref object of RootObj
  origin*: Vec
  x*: Vec
  y*: Vec
  norm*: Vec

type Light* = ref object of RootObj
  intensity*: float

type PointLight* = ref object of Light
  point*: Vec
  atten_coef*: float

type AmbLight* = ref object of Light

type PhongMat* = ref object of RootObj
  diffuse*: Col
  ambient*: Col
  specular*: Col
  shininess*: float
  refrac_n*: float
  is_trans*: bool
  trans_coeff*: float

type Object* = ref object of RootObj
  material*: PhongMat

method collision* (obj: Object, ray: Ray): CollPoint = 
  (-1.0, vector3d(1.0, 0.0, 0.0))
method evalColor* (obj: Object, coll_point: Vec, objList:seq[Object], lightList:seq[Light]): Col =
  (0.0, 0.0, 0.0)
method isShadowed* (obj: Object, coll_Point: Vec, light:Light): bool = false

type PolyObject* = ref object of Object
  poly_vec*: seq[Polygon]
  vmap*: seq[Vec]
  nmap*: seq[Vec]
  bbox*: BoundBox

method collision* (obj: PolyObject, ray: Ray): CollPoint = 
  (-1.0, vector3d(1.0, 0.0, 0.0))
method isShadowed* (obj: PolyObject, coll_Point: Vec, light:Light): bool = false
method evalColor* (obj: PolyObject, coll_point: Vec, objList:seq[Object], lightList:seq[Light]): Col =
  (0.0, 0.0, 0.0)


type Sphere* = ref object of Object
  radius*: float
  center*: Vec

method collision* (obj: Sphere, ray: Ray): CollPoint = 
  (1.0, vector3d(1.0, 0.0, 0.0))
method isShadowed* (obj: Sphere, coll_Point: Vec, light:Light): bool = false
method evalColor* (obj: Sphere, coll_point: Vec, objList:seq[Object], lightList:seq[Light]): Col =
  (0.0, 0.0, 0.0)


## --- procedures ---


proc newScreen* (origin: Vec, x: Vec, y: Vec): Screen {.inline.} =
  var norm = cross(x, y)
  normalize(norm)
  return Screen(origin:origin, x:x, y:y, norm: norm)

proc newRay* (center: Vec, way: Vec): Ray {.inline.} =
  return Ray(center: center, way: way, refrac_n: 1.0, bound_no: 0)

proc getRay* (s: Screen, x:float, y:float): Ray =
  return newRay(s.origin + x * s.x + y * s.y, s.norm)

proc rayToColor* (ray: Ray, objList:seq[Object], lightList:seq[Light], currObj:Object = nil): Col =
  # TODO: currObj check
  var tList = objList.map(proc(obj:Object): CollPoint = obj.collision(ray))
  # TODO: else check
  tList.sort(proc (t0, t1: CollPoint): int =
    if t0.t == -1: 1 elif t1.t == -1: 1 else: int(t0.t - t1.t))
  return (0.0, 0.0, 0.0)






