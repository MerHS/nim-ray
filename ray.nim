import graphics
import colors
import objects.rayobj
import basic3d

var surf = newSurface(500, 500)

let screen = newScreen(vector3d(10.0, -10.0, 10.0), 
                       vector3d(0.0, 20.0, 0.0), 
                       vector3d(0.0, 0.0, -20.0))

var objList: seq[Object]
let mat_turq = 
  PhongMat (diffuse: (0.396, 0.74151, 0.69102),
            ambient: (0.1, 0.18725, 0.1745),
            specular: (0.297254, 0.30829, 0.306678),
            shininess: 12.8,
            trans_coeff: 0.0,
            refrac_n: 1.0,
            is_trans: false)
#let sphere0 = 
#objList.add()

for i in 0..9:
  for j in 0..9:
    surf[i, j] = rgb(100, 2, 0)
for i in 0..20:
  for j in 10..20:
    surf[i, j] = colSalmon

writeToBMP(surf, "ray.bmp")
