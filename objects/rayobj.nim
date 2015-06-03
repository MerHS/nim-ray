import basic3d
import colors
import math

const BOUND_MAX* = 10
const INTENSITY_MIN* = 0.0001

type 
  Col* = tuple[r:float, g:float, b:float]
  Vec* = TVector3d
  BoundBox* = tuple[o:Vec, u:Vec, v:Vec, n:Vec]
  Polygon* = tuple[ai:uint, bi:uint, ci:uint, ani:uint, bni:uint, cni:uint]

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

type PhongMat* = object
  diffuse*: Col
  ambient*: Col
  specular*: Col
  shininess*: float
  refrac_n*: float
  is_trans*: bool
  trans_coeff*: float

type Object* = ref object of RootObj
  material*: PhongMat

type PolyObject* = ref object of Object
  poly_vec*: seq[Polygon]
  vmap*: seq[Vec]
  nmap*: seq[Vec]
  bbox*: BoundBox

type Sphere* = ref object of Object
  radius*: float
  center*: Vec

proc colToRgb (c: Col): Color {.inline.} =
  return rgb(min(c.r.round, 255), min(c.g.round, 255), min(c.b.round, 255))

proc newScreen* (origin: Vec, x: Vec, y: Vec): Screen {.inline.} =
  var norm = cross(x, y)
  normalize(norm)
  return Screen(origin:origin, x:x, y:y, norm: norm)

proc newRay* (center: Vec, way: Vec): Ray {.inline.} =
  return Ray(center: center, way: way, refrac_n: 1.0, bound_no: 0)

proc getRay* (s: Screen, x:float, y:float): Ray =
  return newRay(s.origin + x * s.x + y * s.y, s.norm)