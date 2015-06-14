import basic3d
import colors
import math
import algorithm
import sdl, sdl_image
import graphics

const BOUND_MAX* = 7
const INTENSITY_MIN* = 0.0001
const textBoxSize* = 28.0
const PERTUBE = 0.05

type 
  Col* = tuple[r:float, g:float, b:float]
  Vec* = TVector3d
  BoundBox* = tuple[o:Vec, u:Vec, v:Vec, n:Vec]
  Polygon* = tuple[ai:uint, bi:uint, ci:uint, ani:uint, bni:uint, cni:uint]
  Direction* = enum 
    front, back, left, right, up, down

proc `*`* (c:Col, f:float): Col {.inline, noInit.} = (f*c.r, f*c.g, f*c.b)
proc `*`* (f:float, c:Col): Col {.inline, noInit.} = (f*c.r, f*c.g, f*c.b)
proc `*`* (c0:Col, c:Col): Col {.inline, noInit.} = (c0.r*c.r, c0.g*c.g, c0.b*c.b)
proc `/`* (c:Col, f:float): Col {.inline, noInit.} = (c.r/f, c.g/f, c.b/f)
proc `+`* (c0:Col, c1:Col): Col {.inline, noInit.} = (c0.r + c1.r, c0.g + c1.g, c0.b + c1.b)
proc `+=`* (c0:var Col, c1:Col) {.inline, noInit.} = c0 = c0 + c1
proc `$`* (c:Col): string {.inline, noInit.} = "(" & $(c.r) & ", " & $(c.g) & ", " & $(c.b) & ")"

let texture* = imgLoad("background.bmp")
let textPf* = graphics.Psurface(w:texture.w, h:texture.h, s:texture)
let textBox* = (o:vector3d(-textBoxSize/2, -textBoxSize/2, -textBoxSize/2), u:vector3d(textBoxSize, 0.0, 0.0),
               v:vector3d(0.0, textBoxSize, 0.0), n:vector3d(0.0, 0.0, textBoxSize))

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

proc rayToColor* (ray: Ray, objList:seq[Object], lightList:seq[Light], currObj:Object = nil): Col 
proc boxCollide* (bbox: BoundBox, ray: Ray): tuple[colp:CollPoint, dir:Direction]

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

method collision* (obj: PolyObject, ray: Ray): CollPoint = 
  var colp = obj.bbox.boxCollide(ray).colp
  if colp != nil:
    colp.obj = obj
    return colp
  else: return nil

method isShadowed* (obj: PolyObject, collPoint: CollPoint, objList:seq[Object], light:Light): bool =
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

method evalColor* (obj: PolyObject, ray: Ray, collPoint: CollPoint, 
  objList:seq[Object], lightList:seq[Light]): Col =
  var ret_col: Col = (0.0, 0.0, 0.0)
  
  # Phong Illumination
  for light in lightList:
    if not obj.isShadowed(collPoint, objList, light):
      ret_col += light.lightColor(ray, collPoint)
  
  if ray.bound_no >= BOUND_MAX: return ret_col
  let ref_way = ray.way - 2*ray.way.dot(collPoint.norm) * collPoint.norm
  let (ux_seed, uy_seed) = (random(1.0), random(1.0))
  var u = vector3d(ux_seed, uy_seed, -(ref_way.x * ux_seed + ref_way.y * uy_seed)/ref_way.z)
  var v = ref_way.cross(u)
  u.normalize()
  v.normalize()
  # Specular Reflection
  #let ref_ray1 = Ray(center: collPoint.point, way: ref_way + PERTUBE * ((0.5 - random(1.0)) * u + (0.5 - random(1.0)) * v), 
  #                   refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  let ref_ray1 = Ray(center: collPoint.point, way: ref_way + PERTUBE * (random(0.5) * u + random(0.5) * v), 
                    refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  let ref_ray2 = Ray(center: collPoint.point, way: ref_way + PERTUBE * (random(0.5) * u + -random(0.5) * v), 
                    refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  let ref_ray3 = Ray(center: collPoint.point, way: ref_way + PERTUBE * (-random(0.5) * u + random(0.5) * v), 
                    refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  let ref_ray4 = Ray(center: collPoint.point, way: ref_way + PERTUBE * (-random(0.5) * u + -random(0.5) * v), 
                    refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  #if obj.material.is_trans == false:
  #ret_col += obj.material.specular * ref_ray.rayToColor(objList, lightList, obj)
  ret_col += obj.material.specular * (ref_ray1.rayToColor(objList, lightList, obj) +
                                      ref_ray2.rayToColor(objList, lightList, obj) +
                                      ref_ray3.rayToColor(objList, lightList, obj) +
                                      ref_ray4.rayToColor(objList, lightList, obj)) / 4.0
  return ret_col

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
  if t0 >= 0.001:
    let point = ray.center + t0 * ray.way
    var norm = point - obj.center 
    norm.normalize() 
    return CollPoint(t:t0, point: point, norm:norm, obj:obj)
  elif t0 < 0.001 and t1 >= 0:
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
  
  # Phong Illumination
  for light in lightList:
    if not obj.isShadowed(collPoint, objList, light):
      ret_col += light.lightColor(ray, collPoint)
  
  if ray.bound_no >= BOUND_MAX: return ret_col
  let ref_way = ray.way - 2*ray.way.dot(collPoint.norm) * collPoint.norm
  let (ux_seed, uy_seed) = (random(1.0), random(1.0))
  var u = vector3d(ux_seed, uy_seed, -(ref_way.x * ux_seed + ref_way.y * uy_seed)/ref_way.z)
  var v = ref_way.cross(u)
  u.normalize()
  v.normalize()
  # Specular Reflection
  #let ref_ray1 = Ray(center: collPoint.point, way: ref_way + PERTUBE * ((0.5 - random(1.0)) * u + (0.5 - random(1.0)) * v), 
  #                   refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  let ref_ray1 = Ray(center: collPoint.point, way: ref_way + PERTUBE * (random(0.5) * u + random(0.5) * v), 
                    refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  let ref_ray2 = Ray(center: collPoint.point, way: ref_way + PERTUBE * (random(0.5) * u + -random(0.5) * v), 
                    refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  let ref_ray3 = Ray(center: collPoint.point, way: ref_way + PERTUBE * (-random(0.5) * u + random(0.5) * v), 
                    refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  let ref_ray4 = Ray(center: collPoint.point, way: ref_way + PERTUBE * (-random(0.5) * u + -random(0.5) * v), 
                    refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  #if obj.material.is_trans == false:
  #ret_col += obj.material.specular * ref_ray.rayToColor(objList, lightList, obj)
  ret_col += obj.material.specular * (ref_ray1.rayToColor(objList, lightList, obj) +
                                      ref_ray2.rayToColor(objList, lightList, obj) +
                                      ref_ray3.rayToColor(objList, lightList, obj) +
                                      ref_ray4.rayToColor(objList, lightList, obj)) / 4.0
  discard """else:  # Specular Refraction
    var ray_norm = ray.way
    ray_norm.normalize()
    var theta: float
    var refrac_way: Vec
    var refrac_n: float
    var k: Col = (1.0, 1.0, 1.0)
    let dn = ray_norm.dot(collPoint.norm)
    if dn < 0: # extern to internal
      refrac_n = obj.material.refrac_n
      theta = -ray_norm.dot(collPoint.norm)
      refrac_way = (ray_norm - collPoint.norm*dn)/refrac_n - collPoint.norm * sqrt(1 - (1 - dn*dn) / (refrac_n*refrac_n))
      refrac_way.normalize()
    elif (ray.refrac_n * ray.refrac_n) * (1 - dn*dn) > 1 :
      return ret_col + obj.material.specular * ref_ray.rayToColor(objList, lightList, obj) 
    else:
      k = k * exp(-0.5*collPoint.t)
      refrac_n = ray.refrac_n
      refrac_way = refrac_n*(ray_norm - collPoint.norm*dn) - collPoint.norm * sqrt(1 - (refrac_n*refrac_n) * (1 - dn*dn))
      refrac_n = 1.0 
      refrac_way.normalize()
      theta = refrac_way.dot(collPoint.norm)
    let tcoeff = obj.material.trans_coeff
    let r = 0.0 # tcoeff + (1 - tcoeff) * (1 - theta).pow(5)
    let refrac_ray = Ray(center: collPoint.point, way: refrac_way, refrac_n: refrac_n, bound_no: ray.bound_no + 1)
    ret_col +=
      k * (r * obj.material.specular * ref_ray.rayToColor(objList, lightList, obj) +
           (1 - r) * obj.material.specular * refrac_ray.rayToColor(objList, lightList, obj))"""
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

  if ret_ts.ut0 > 0.0: # front
    let 
      coll = ray.center + ret_ts.ut0 * ray.way - bbox.o
      collv = coll.dot(bbox.v)
      colln = coll.dot(bbox.n)
    if (not (0 <= collv and collv <= llv)) or (not (0 <= colln and colln <= lln)):
      ret_ts.ut0 = 0.0
    collp.point = coll + bbox.o 
    collp.t = ret_ts.ut0
    collp.norm = -bbox.u
    ret_dir = front

  if ret_ts.ut1 > 0.0: # back
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
      ret_dir = back

  if ret_ts.vt0 > 0.0: # left
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
      ret_dir = left

  if ret_ts.vt1 > 0.0: # right
    let 
      coll = ray.center + ret_ts.vt1 * ray.way - (bbox.o + bbox.v)
      collu = coll.dot(bbox.u)
      colln = coll.dot(bbox.n)
    if (not (0 <= collu and collu <= llu)) or (not (0 <= colln and colln <= lln)):
      ret_ts.vt1 = 0.0
    elif collp.t == 0.0 or collp.t > ret_ts.vt1:
      collp.point = coll + (bbox.o + bbox.v)
      collp.t = ret_ts.vt1
      collp.norm = bbox.v
      ret_dir = right

  if ret_ts.nt0 > 0.0: # down
    let 
      coll = ray.center + ret_ts.nt0 * ray.way - bbox.o
      collv = coll.dot(bbox.v)
      collu = coll.dot(bbox.u)
    if (not (0 <= collv and collv <= llv)) or (not (0 <= collu and collu <= llu)):
      ret_ts.nt0 = 0.0
    elif collp.t == 0.0 or collp.t > ret_ts.nt0:
      collp.point = coll + bbox.o
      collp.t = ret_ts.nt0
      collp.norm = -bbox.n
      ret_dir = down

  if ret_ts.nt1 > 0.0: # up
    let 
      coll = ray.center + ret_ts.nt1 * ray.way - (bbox.o + bbox.n)
      collv = coll.dot(bbox.v)
      collu = coll.dot(bbox.u)
    if (not (0 <= collv and collv <= llv)) or (not (0 <= collu and collu <= llu)):
      ret_ts.nt1 = 0.0
    elif collp.t == 0.0 or collp.t > ret_ts.nt1:
      collp.point = coll + (bbox.o + bbox.n)
      collp.t = ret_ts.nt1
      collp.norm = bbox.n
      ret_dir = up

  if collp.t == 0.0: 
    return (nil, front)
  collp.norm.normalize()
  return (collp, ret_dir)

let textSphere = Sphere(radius:sqrt(0.75 * textBoxSize * textBoxSize), center:vector3d(0.0, 0.0, 0.0), material:nil)

proc rayToBackColor* (ray: Ray): Col =
  let colpoint = textSphere.collision(ray)
  var pixelDir: Vec
  var pixelCol: tuple[r, g, b: range[0 .. 255]]
  var dir: Direction
  if colpoint == nil:
    return (0.2, 0.5, 0.5)
  var colWay = colpoint.point
  colWay.normalize()
  let colp = textBox.boxCollide(newRay(vector3d(0.0, 0.0, 0.0), colWay))
  if colp.colp == nil:
    return (0.2, 0.5, 0.5)

  if colp.dir == front:
    pixelDir = (colp.colp.point - textBox.o) / textBoxSize
    pixelCol = textPf[int(256 * pixelDir.y) + 256, 255 - int(256 * pixelDir.z)].extractRGB()
  elif colp.dir == back:
    pixelDir = (colp.colp.point - (textBox.o + textBox.u)) / textBoxSize
    pixelCol = textPf[int(256 * pixelDir.y) + 256, 512 + int(256 * pixelDir.z)].extractRGB()
  elif colp.dir == left:
    pixelDir = (colp.colp.point - textBox.o) / textBoxSize
    pixelCol = textPf[256 - int(256 * pixelDir.z), 257 + int(256 * pixelDir.x)].extractRGB()
  elif colp.dir == right:
    pixelDir = (colp.colp.point - (textBox.o + textBox.v)) / textBoxSize
    pixelCol = textPf[512 + int(256 * pixelDir.z), 257 + int(256 * pixelDir.x)].extractRGB()
  elif colp.dir == up:
    pixelDir = (colp.colp.point - (textBox.o + textBox.n)) / textBoxSize
    pixelCol = textPf[1023 - int(256 * pixelDir.y), 257 + int(256 * pixelDir.x)].extractRGB()
  elif colp.dir == down:
    pixelDir = (colp.colp.point - textBox.o) / textBoxSize
    pixelCol = textPf[int(256 * pixelDir.y) + 256, 257 + int(256 * pixelDir.x)].extractRGB()

  return (r:pixelCol.r/255, g:pixelCol.g/255, b:pixelCol.b/255)

proc newScreen* (origin: Vec, x: Vec, y: Vec): Screen {.inline.} =
  var norm = x.cross(y)
  normalize(norm)
  return Screen(origin:origin, x:x, y:y, norm: norm)

proc newRay* (center: Vec, way: Vec): Ray =
  return Ray(center: center, way: way, refrac_n: 1.0, bound_no: 0)

proc getRay* (s: Screen, x:float, y:float): Ray {.inline.} =
  return newRay(s.origin + x * s.x + y * s.y, s.norm)

proc getRay* (fs: Screen, bs:Screen, x:float, y:float): Ray {.inline.} = 
  let newCenter = fs.origin + x * fs.x + y * fs.y
  var newWay = bs.origin + x*bs.x + y*bs.y - newCenter
  newWay.normalize()
  return newRay(newCenter, newWay)

proc depthColor* (fs:Screen, bs:Screen, x:float, y:float, 
  objList:seq[Object], lightList:seq[Light]): Col =
  var rcol: Col = (0.0, 0.0, 0.0)
  let newTarget = (fs.origin + x * fs.x + y * fs.y + bs.origin + x * bs.x + y * bs.y) / 2.0
  var newWay: Vec
  var newCenter: Vec

  for _ in 0..3:
    newCenter = fs.origin + (x + random(0.01)) * fs.x + (y + random(0.01)) * fs.y
    newWay = newTarget - newCenter
    newWay.normalize()
    rcol += rayToColor(newRay(newCenter, newWay), objList, lightList)

  rcol = rcol / 4.0
  return rcol

proc rayToColor* (ray: Ray, objList:seq[Object], lightList:seq[Light], currObj:Object = nil): Col =
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
  #let rayPlus = Ray(center: ray.center, way: ray.way, refrac_n: ray.refrac_n, bound_no: ray.bound_no + 1)
  return hitPoint.obj.evalColor(ray, hitPoint, objList, lightList)



