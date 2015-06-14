import graphics
import colors
import objects.rayobj
import basic3d
import math

const width = 500
const height = 500
const winv = 0.5/width
const hinv = 0.5/height

randomize()
proc colToRgb (col: Col): Color {.inline.} =
  let c = 255.0 * col
  return rgb(min(c.r.round, 255), min(c.g.round, 255), min(c.b.round, 255))

var surf = newSurface(width, height)

let screen = newScreen(vector3d(10.0, -9.0, 10.0), 
                       vector3d(0.0, 20.0, 0.0), 
                       vector3d(0.0, 0.0, -20.0))

let backscreen = newScreen(vector3d(-12.0, -15.0, 16.0), 
                           vector3d(0.0, 32.0, 0.0), 
                           vector3d(0.0, 0.0, -32.0))

var objList = newSeq[Object]()
var lightList = newSeq[Light]()

## --- Insert Lights
lightList.add(AmbLight(intensity: 1.0))
discard """lightList.add(PointLight(intensity: 1.0, 
                         point:vector3d(5.0, -5.0, 0.0),
                         atten_coef:0.001))"""
var way0 = vector3d(1.0, 2.0, 2.0)
way0.normalize()
lightList.add(AreaLight(intensity:1.0, way:way0))

## --- Insert Object ---
let mat_emerald = 
  PhongMat (diffuse: (0.07568, 0.61424, 0.07568),
            ambient: (0.0215, 0.1745, 0.0215),
            specular: (0.633, 0.727811, 0.633),
            shininess: 128 * 0.6,
            trans_coeff: (0.566 * 0.566)/(2.566 * 2.566),
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

discard """let tetra =
  PolyObject(poly_vec:newSeq((),
                             (),
                             (),
                             ()),
             vmap:newSeq(vector3d(), vector3d(),
                         vector3d(), vector3d()),
             nmap:newSeq(vector3d(), vector3d(),
                         vector3d(), vector3d()),
             bbox:(o:vector3d(),
                   u:vector3d(),
                   v:vector3d(),
                   n:vector3d()))"""

objList.add(sphere0)
objList.add(sphere1)

## --- Generate BMP files ---
for x in 0..(width - 1):
  for y in 0..(height - 1):
    #let rcol = rayToColor(screen.getRay(backScreen, x/width, y/height), objList, lightList)
    # TODO: No Discard Anti Aliasing
    let
      rcol0 = rayToColor(screen.getRay(backScreen, x/width + random(winv), y/height + random(hinv)), objList, lightList)
      rcol1 = rayToColor(screen.getRay(backScreen, x/width + winv + random(winv), y/height + random(hinv)), objList, lightList)
      rcol2 = rayToColor(screen.getRay(backScreen, x/width + random(winv), y/height + hinv + random(hinv)), objList, lightList)
      rcol3 = rayToColor(screen.getRay(backScreen, x/width + winv + random(winv), y/height + hinv +random(hinv)), objList, lightList)
      rcol = (r:(rcol0.r + rcol1.r + rcol2.r + rcol3.r) / 4,
              g:(rcol0.g + rcol1.g + rcol2.g + rcol3.g) / 4,
              b:(rcol0.b + rcol1.b + rcol2.b + rcol3.b) / 4)
    try:
      surf[x, y] = colToRgb (rcol)
    except:
      let ray = screen.getRay(x/width, y/height)
      let col_p = sphere0.collision(ray)
      #echo repr(lightList[1].lightColor(ray, col_p))
      echo "x: ", x, " y: ", y, " col: ", rcol, " p: ", col_p.point
      raise

writeToBMP(surf, "ray.bmp")

discard """let
  scray = screen.getRay(0.5, 0.4)
  sp0col = sphere0.collision(scray)
  l1 = AreaLight(intensity:1.0, way:way0)
echo repr(textBox.boxCollide(scray))
#echo rayToColor(scray, objList, lightList, nil)"""



