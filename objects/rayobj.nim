import basic3d
import colors
import math
import algorithm
import sdl, sdl_image
import graphics

const BOUND_MAX* = 10
const INTENSITY_MIN* = 0.0001

type 
  Col* = tuple[r:float, g:float, b:float]
  Vec* = TVector3d
  BoundBox* = tuple[o:Vec, u:Vec, v:Vec, n:Vec]
  Polygon* = tuple[ai:uint, bi:uint, ci:uint, ani:uint, bni:uint, cni:uint]
  Direction* = enum 
    front, back, left, right, up, down

proc `*`* (c:Col, f:float): Col {.inline, noInit.} = (f*c.r, f*c.g, f*c.b)
proc `*`* (f:float, c:Col): Col {.inline, noInit.} = (f*c.r, f*c.g, f*c.b)
proc `+`* (c0:Col, c1:Col): Col {.inline, noInit.} = (c0.r + c1.r, c0.g + c1.g, c0.b + c1.b)
proc `+=`* (c0:var Col, c1:Col) {.inline, noInit.} = c0 = c0 + c1
proc `$`* (c:Col): string {.inline, noInit.} = "(" & $(c.r) & ", " & $(c.g) & ", " & $(c.b) & ")"

let texture = imgLoad("background.bmp")
let textPf = graphics.Psurface(w:texture.w, h:texture.h, s:texture)
let textBox = (o:vector3d(-50.0, -50.0, -50.0), u:vector3d(100.0, 0.0, 0.0),
               v:vector3d(0.0, 100.0, 0.0), n:vector3d(0.0, 0.0, 100.0))

type Ray* = ref object of RootObj
  center*: Vec
  way*: Vec
  refrac_n*: float # current refraction index
  bound_no*: int
proc newRay* (center: Vec, way: Vec): Ray {.inline.}

type Screen* = ref object of RootObj
  origin*: Vec
  x*: Vec
  y*: Vec
  norm*: Vec

type Light* = ref object of RootObj
  intensity*: float

type AmbLight* = ref object of Light
type AreaLight* = ref object of Light
  way*: Vec
type PointLight* = ref object of Light
  point*: Vec
  atten_coef*: float

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

type CollPoint* = ref object of RootObj
  t*: float
  point*: Vec
  norm*: Vec
  obj*: Object

method lightColor* (light:Light, ray: Ray, collPoint: CollPoint): Col =
  return light.intensity * Col((1.0, 1.0, 1.0))

method lightColor* (light:AmbLight, ray: Ray, collPoint: CollPoint): Col =
  return light.intensity * collPoint.obj.material.ambient
  
method lightColor* (light:AreaLight, ray:Ray, collPoint: CollPoint): Col =
  let 
    mat = collPoint.obj.material
    light_cos = abs(light.way.dot(collPoint.norm))
    ref_ray = -light.way + 2 * light_cos * collPoint.norm
  var ret_col = mat.diffuse * (light.intensity * light_cos)
  let spec_cos = ref_ray.dot(-ray.way)
  if spec_cos > 0:
    ret_col += mat.specular * (light.intensity * spec_cos.pow(mat.shininess))
  return ret_col

method lightColor* (light:PointLight, ray: Ray, collPoint: CollPoint): Col =
  var ret_col: Col
  let 
    point = collPoint.point
    mat = collPoint.obj.material
  var light_ray = (light.point - point)
  let
    light_dist = light_ray.dot(light_ray)
    p_inten = 1.0 / (light.intensity + light.atten_coef * light_dist)
  if p_inten < INTENSITY_MIN:
    return (0.0, 0.0, 0.0)
  light_ray.normalize()
  # -- diffuse --
  ret_col = mat.diffuse * (p_inten * collPoint.norm.dot(light_ray)) 
  # -- specular --
  let ref_ray = -light_ray + 2 * (light_ray.dot(-collPoint.norm)) * collPoint.norm
  let spec_cos = ref_ray.dot(-ray.way)
  if spec_cos > 0:
    ret_col += mat.specular * (p_inten * spec_cos.pow(mat.shininess))
  return ret_col

method collision* (obj: Object, ray: Ray): CollPoint = nil
method isShadowed* (obj: Object, collPoint: CollPoint, light:Light): bool = false
method evalColor* (obj: Object, ray: Ray, collPoint: CollPoint, 
  objList:seq[Object], lightList:seq[Light]): Col =
  (0.0, 0.0, 0.0)


type PolyObject* = ref object of Object
  poly_vec*: seq[Polygon]
  vmap*: seq[Vec]
  nmap*: seq[Vec]
  bbox*: BoundBox

method collision* (obj: PolyObject, ray: Ray): CollPoint = nil
method isShadowed* (obj: PolyObject, collPoint: CollPoint, light:Light): bool = false
method evalColor* (obj: PolyObject, ray: Ray, collPoint: CollPoint, 
  objList:seq[Object], lightList:seq[Light]): Col =
  (0.0, 0.0, 0.0)


type Sphere* = ref object of Object
  radius*: float
  center*: Vec

method collision* (obj: Sphere, ray: Ray): CollPoint = 
  let 
    e_c = ray.center - obj.center
    dd = ray.way.dot(ray.way)
    discrement = (ray.way.dot(e_c)) * (ray.way.dot(e_c)) - dd * (e_c.dot(e_c) - obj.radius * obj.radius)
  if discrement < 0:
    return nil
  let 
    t1 = (-ray.way.dot(e_c) + sqrt(discrement))/dd
    t0 = (-ray.way.dot(e_c) - sqrt(discrement))/dd
  if t0 >= 0:
    let point = ray.center + t0 * ray.way
    var norm = point - obj.center 
    norm.normalize() 
    return CollPoint(t:t0, point: point, norm:norm, obj:obj)
  elif t0 < 0 and t1 >= 0:
    let point = ray.center + t1 * ray.way
    var norm = point - obj.center 
    norm.normalize() 
    return CollPoint(t:t1, point: point, norm:norm, obj:obj)
  else:
    return nil

method isShadowed* (obj: Sphere, collPoint: CollPoint, objList:seq[Object], light:Light): bool =
  if light of AmbLight:
    return false
  elif light of PointLight:
    var lightWay = PointLight(light).point - collPoint.point
    if lightWay.dot(collPoint.norm) < 0:
      return true
    elif len(objList) < 2: # only obj is in objList
      return false
    lightWay.normalize()
    let lightRay = newRay(collPoint.point, lightWay)
    for otherObj in objList:
      if otherObj == obj: continue
      if otherObj.collision(lightRay) != nil: return true
    return false
  elif light of AreaLight: 
    var lightWay = AreaLight(light).way
    if lightWay.dot(collPoint.norm) < 0:
      return true
    elif len(objList) < 2: # only obj is in objList
      return false
    lightWay.normalize()
    let lightRay = newRay(collPoint.point, lightWay)
    for otherObj in objList:
      if otherObj == obj: continue
      if otherObj.collision(lightRay) != nil: return true
    return false
  else:
    return true

method evalColor* (obj: Sphere, ray: Ray, collPoint: CollPoint, 
  objList:seq[Object], lightList:seq[Light]): Col =
  var ret_col: Col = (0.0, 0.0, 0.0)
  for light in lightList:
    if not obj.isShadowed(collPoint, objList, light):
      ret_col += light.lightColor(ray, collPoint)
  return ret_col

## --- procedures ---

proc boxCollide* (bbox: BoundBox, ray: Ray): tuple[colp:CollPoint, dir:Direction] =
  let
    llu = bbox.u.sqrLen()
    llv = bbox.v.sqrLen()
    lln = bbox.n.sqrLen()
    p_o = ray.center - bbox.o
    ux = bbox.u.dot(ray.way)
    vx = bbox.v.dot(ray.way)
    nx = bbox.n.dot(ray.way)
  var ret_ts = (ut0: 0.0, ut1: 0.0, vt0: 0.0, vt1: 0.0, nt0: 0.0, nt1: 0.0)
  var ret_dir = front
  if ux != 0.0:
    ret_ts.ut0 = -(bbox.u.dot(p_o)) / ux
    ret_ts.ut1 = -(bbox.u.dot(p_o) - llu) / ux
  if vx != 0.0:
    ret_ts.vt0 = -(bbox.v.dot(p_o)) / vx
    ret_ts.vt1 = -(bbox.v.dot(p_o) - llv) / vx
  if nx != 0.0:
    ret_ts.nt0 = -(bbox.n.dot(p_o)) / nx
    ret_ts.nt1 = -(bbox.n.dot(p_o) - lln) / nx

  var collp = CollPoint()
  collp.obj = nil

  if ret_ts.ut0 > 0.0: # left
    let 
      coll = ray.center + ret_ts.ut0 * ray.way - bbox.o
      collv = coll.dot(bbox.v)
      colln = coll.dot(bbox.n)
    if (not (0 <= collv and collv <= llv)) or (not (0 <= colln and colln <= lln)):
      ret_ts.ut0 = 0.0
    collp.point = coll + bbox.o 
    collp.t = ret_ts.ut0
    collp.norm = -bbox.u
    ret_dir = left

  if ret_ts.ut1 > 0.0: # right
    let
      coll = ray.center + ret_ts.ut1 * ray.way - (bbox.o + bbox.u)
      collv = coll.dot(bbox.v)
      colln = coll.dot(bbox.n)
    if (not (0 <= collv and collv <= llv)) or (not (0 <= colln and colln <= lln)):
      ret_ts.ut1 = 0.0
    elif collp.t == 0.0 or collp.t > ret_ts.ut1:
      collp.point = coll + (bbox.o + bbox.u)
      collp.t = ret_ts.ut1
      collp.norm = bbox.u
      ret_dir = right

  if ret_ts.vt0 > 0.0: # down
    let 
      coll = ray.center + ret_ts.vt0 * ray.way - bbox.o
      collu = coll.dot(bbox.u)
      colln = coll.dot(bbox.n)
    if (not (0 <= collu and collu <= llu)) or (not (0 <= colln and colln <= lln)):
      ret_ts.vt0 = 0.0
    elif collp.t == 0.0 or collp.t > ret_ts.vt0:
      collp.point = coll + bbox.o
      collp.t = ret_ts.vt0
      collp.norm = -bbox.v
      ret_dir = down

  if ret_ts.vt1 > 0.0: # up
    let 
      coll = ray.center + ret_ts.ut1 * ray.way - (bbox.o + bbox.v)
      collu = coll.dot(bbox.u)
      colln = coll.dot(bbox.n)
    if (not (0 <= collu and collu <= llu)) or (not (0 <= colln and colln <= lln)):
      ret_ts.vt1 = 0.0
    elif collp.t == 0.0 or collp.t > ret_ts.vt1:
      collp.point = coll + (bbox.o + bbox.v)
      collp.t = ret_ts.vt1
      collp.norm = bbox.v
      ret_dir = up

  if ret_ts.nt0 > 0.0: # front
    let 
      coll = ray.center + ret_ts.ut0 * ray.way - bbox.o
      collv = coll.dot(bbox.v)
      collu = coll.dot(bbox.u)
    if (not (0 <= collv and collv <= llv)) or (not (0 <= collu and collu <= llu)):
      ret_ts.nt0 = 0.0
    elif collp.t == 0.0 or collp.t > ret_ts.nt0:
      collp.point = coll + bbox.o
      collp.t = ret_ts.nt0
      collp.norm = -bbox.n
      ret_dir = front

  if ret_ts.nt1 > 0.0: # back
    let 
      coll = ray.center + ret_ts.ut1 * ray.way - (bbox.o + bbox.n)
      collv = coll.dot(bbox.v)
      collu = coll.dot(bbox.u)
    if (not (0 <= collv and collv <= llv)) or (not (0 <= collu and collu <= llu)):
      ret_ts.nt1 = 0.0
    elif collp.t == 0.0 or collp.t > ret_ts.nt1:
      collp.point = coll + (bbox.o + bbox.n)
      collp.t = ret_ts.nt1
      collp.norm = bbox.n
      ret_dir = back

  if collp.t == 0.0: 
    return (nil, front)
  collp.norm.normalize()
  return (collp, ret_dir)

proc rayToBackColor* (ray: Ray): Col {.inline.} =
  let colPos = boxCollide(textBox, ray)
  if colPos.dir == front:
    return (0.0, 0.0, 0.1)
  #if colPos.point.x == -50.0
  return (0.1, 0.0, 0.0)

proc newScreen* (origin: Vec, x: Vec, y: Vec): Screen {.inline.} =
  var norm = x.cross(y)
  normalize(norm)
  return Screen(origin:origin, x:x, y:y, norm: norm)

proc newRay* (center: Vec, way: Vec): Ray =
  return Ray(center: center, way: way, refrac_n: 1.0, bound_no: 0)

proc getRay* (s: Screen, x:float, y:float): Ray {.inline.} =
  return newRay(s.origin + x * s.x + y * s.y, s.norm)

proc rayToColor* (ray: Ray, objList:seq[Object], lightList:seq[Light], currObj:Object = nil): Col {.inline.} =
  var tList = objList.map(proc(obj:Object): CollPoint = 
    if obj == currObj: nil
    else: obj.collision(ray))

  tList.sort(proc (t0, t1: CollPoint): int =
    if t0 == nil : 1 elif t1 == nil: -1 else: system.cmp[float](t0.t, t1.t))

  var hitPoint: CollPoint
  if tList[0] == nil: # hit background
    return rayToBackColor(ray)
  else:
    hitPoint = tlist[0]

  return hitPoint.obj.evalColor(ray, hitPoint, objList, lightList)



