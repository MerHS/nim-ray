import graphics
import colors
import objects.rayobj
import basic3d
import math

const width = 500
const height = 500

proc colToRgb (col: Col): Color {.inline.} =
  let c = 255.0 * col
  return rgb(min(c.r.round, 255), min(c.g.round, 255), min(c.b.round, 255))

var surf = newSurface(width, height)

let screen = newScreen(vector3d(10.0, -10.0, 10.0), 
                       vector3d(0.0, 20.0, 0.0), 
                       vector3d(0.0, 0.0, -20.0))

var objList = newSeq[Object]()
var lightList = newSeq[Light]()

## --- Insert Lights
lightList.add(AmbLight(intensity: 0.1))
discard """lightList.add(PointLight(intensity: 1.0, 
                         point:vector3d(5.0, -5.0, 0.0),
                         atten_coef:0.001))"""
var way0 = vector3d(0.2, -1.0, 0.0)
way0.normalize()
lightList.add(AreaLight(intensity:1.0, way:way0))

## --- Insert Object ---
let mat_emerald = 
  PhongMat (diffuse: (0.07568, 0.61424, 0.07568),
            ambient: (0.0215, 0.1745, 0.0215),
            specular: (0.633, 0.727811, 0.633),
            shininess: 128 * 0.6,
            trans_coeff: 0.5,
            refrac_n: 1.566,
            is_trans: true)

let mat_turq =
  PhongMat (diffuse: (0.396, 0.74151, 0.69102),
            ambient: (0.1, 0.18725, 0.1745),
            specular: (0.297254, 0.30829, 0.306678),
            shininess: 12.8,
            trans_coeff: 0.0,
            refrac_n: 1.0,
            is_trans: false)

let sphere0 = 
  Sphere (radius:5.0, center:vector3d(0.0, 0.0, 0.0), material: mat_emerald)
let sphere1 =
  Sphere (radius:2.0, center:vector3d(0.0, 8.0, 0.0), material: mat_turq)

objList.add(sphere0)
objList.add(sphere1)

## --- Generate BMP files ---
for x in 0..(width - 1):
  for y in 0..(height - 1):
    let rcol = rayToColor(screen.getRay(x/width, y/height), objList, lightList)
    try:
      surf[x, y] = colToRgb (rcol)
    except:
      let ray = screen.getRay(x/width, y/height)
      let col_p = sphere0.collision(ray)
      #echo repr(lightList[1].lightColor(ray, col_p))
      echo "x: ", x, " y: ", y, " col: ", rcol, " p: ", col_p.point
      raise

writeToBMP(surf, "ray.bmp")




