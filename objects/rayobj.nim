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

proc `*`* (c:Col, f:float): Col {.inline, noInit.} = (f*c.r, f*c.g, f*c.b)
proc `*`* (f:float, c:Col): Col {.inline, noInit.} = (f*c.r, f*c.g, f*c.b)

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
  
type CollPoint* = tuple[t:float, norm: Vec, obj:Object]

method collision* (obj: Object, ray: Ray): CollPoint = 
  (-1.0, vector3d(1.0, 0.0, 0.0), obj) # if it's not collided, return -1
method isShadowed* (obj: Object, coll_Point: Vec, light:Light): bool = false
method evalColor* (obj: Object, ray: Ray, coll_point: CollPoint, 
  objList:seq[Object], lightList:seq[Light]): Col =
  (0.0, 0.0, 0.0)


type PolyObject* = ref object of Object
  poly_vec*: seq[Polygon]
  vmap*: seq[Vec]
  nmap*: seq[Vec]
  bbox*: BoundBox

method collision* (obj: PolyObject, ray: Ray): CollPoint = 
  (-1.0, vector3d(1.0, 0.0, 0.0), obj)
method isShadowed* (obj: PolyObject, coll_Point: Vec, light:Light): bool = false
method evalColor* (obj: PolyObject, ray: Ray, coll_point: CollPoint, 
  objList:seq[Object], lightList:seq[Light]): Col =
  (0.0, 0.0, 0.0)


type Sphere* = ref object of Object
  radius*: float
  center*: Vec

method collision* (obj: Sphere, ray: Ray): CollPoint = 
  let e_c = ray.center - obj.center
  let dd = ray.way.dot(ray.way)
  let discrement = (ray.way.dot(e_c)) * (ray.way.dot(e_c)) - dd * (e_c.dot(e_c) - obj.radius * obj.radius)
  if discrement < 0:
    return (-1.0, vector3d(1.0, 0.0, 0.0), obj)
  let t1 = (-ray.way.dot(e_c) + sqrt(discrement))/dd
  let t0 = (-ray.way.dot(e_c) - sqrt(discrement))/dd
  if t0 >= 0:
    var norm = ray.center + t0 * ray.way - obj.center 
    norm.normalize() 
    return (t0, norm, obj)
  elif t0 < 0 and t1 >= 0:
    var norm = ray.center + t1 * ray.way - obj.center 
    norm.normalize() 
    return (t1, norm, obj)
  else:
    return (-1.0, vector3d(1.0, 0.0, 0.0), obj)

method isShadowed* (obj: Sphere, coll_Point: Vec, light:Light): bool = false
method evalColor* (obj: Sphere, ray: Ray, coll_point: CollPoint, 
  objList:seq[Object], lightList:seq[Light]): Col =
  (1.0, 0.0, 0.0)


## --- procedures ---
proc rayToBackColor* (ray: Ray): Col =
  return (0.0, 0.0, 0.0)

proc newScreen* (origin: Vec, x: Vec, y: Vec): Screen {.inline.} =
  var norm = x.cross(y)
  normalize(norm)
  return Screen(origin:origin, x:x, y:y, norm: norm)

proc newRay* (center: Vec, way: Vec): Ray {.inline.} =
  return Ray(center: center, way: way, refrac_n: 1.0, bound_no: 0)

proc getRay* (s: Screen, x:float, y:float): Ray =
  return newRay(s.origin + x * s.x + y * s.y, s.norm)

proc rayToColor* (ray: Ray, objList:seq[Object], lightList:seq[Light], currObj:Object = nil): Col =
  var tList = objList.map(proc(obj:Object): CollPoint = 
    if obj == currObj: (-1.0, vector3d(1.0, 0.0, 0.0), obj)
    else: obj.collision(ray))

  tList.sort(proc (t0, t1: CollPoint): int =
    if t0.t < 0: 1 elif t1.t < 0: 1 else: system.cmp[float](t0.t, t1.t))

  var hitPoint: CollPoint
  if tList[0].t < 0.0: # hit background
    return rayToBackColor(ray)
  elif tList[0].obj == currObj: # tlist[0] == currObj
    if tList.len == 1:
      return rayToBackColor(ray)
    hitPoint = tList[1]
  else:
    hitPoint = tlist[0]

  return hitPoint.obj.evalColor(ray, hitPoint, objList, lightList)






