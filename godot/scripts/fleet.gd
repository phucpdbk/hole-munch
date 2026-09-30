extends RefCounted

const NAMES = ["Trinh sát bạc", "Đĩa sao Thổ", "Đĩa tàng hình", "Đĩa hoàng kim", "Đĩa băng lam", "Tên lửa bạc", "Tên lửa đỏ", "Tên lửa đôi"]
const COLORS = ["77e6dc","b09aff","ffd15c","7cbcff","ff9bbf","78dbe8","ff8974","ffb34c"]
var m
var parts: Array = []

func part(shape: String, pos: Vector3, scale: Vector3, color: String, rot := Vector3.ZERO) -> void:
	parts.append(m.piece(shape,pos,scale,Color(color),rot))

# The rival's hostile saucer: dark hull, red dome and warning lights, never a player skin.
func rival(models) -> ArrayMesh:
	m = models
	parts.clear()
	part("cyl",Vector3.ZERO,Vector3(1.45,0.22,1.45),"2b2530")
	part("smooth",Vector3(0,0.2,0),Vector3(1.15,0.36,1.15),"3d3440")
	part("hemi",Vector3(0,0.32,0),Vector3(0.68,0.7,0.68),"ff5a4e")
	part("ring",Vector3(0,-0.08,0),Vector3(1.6,0.16,1.6),"ff5a4e")
	for i in 6:
		var a := i*TAU/6
		part("box",Vector3(cos(a)*1.55,0,sin(a)*1.55),Vector3(0.55,0.1,0.2),"3d3440",Vector3(0,-a,0))
		part("ball",Vector3(cos(a)*1.1,-0.14,sin(a)*1.1),Vector3.ONE*0.13,"ffe066")
	return m.bake(parts)

func build(models, index: int) -> ArrayMesh:
	m = models
	parts.clear()
	var c: String = COLORS[index]
	match index:
		0,1:
			part("smooth",Vector3.ZERO,Vector3(1.65,0.22,1.65),"d6e5ef" if index == 0 else "6657ac")
			part("hemi",Vector3(0,0.15,0),Vector3(0.8,0.75,0.8),c)
			part("ring",Vector3(0,-0.08,0),Vector3(1.55,0.18,1.55),c)
			for i in 8:
				var a := i*TAU/8
				part("ball",Vector3(cos(a)*1.35,0.12,sin(a)*1.35),Vector3.ONE*0.12,"fff2bc")
			if index == 1: part("ring",Vector3.ZERO,Vector3(2.1,0.12,2.1),"ffc985",Vector3(0.28,0,0.18))
		2,3,4:
			var hull := "324359" if index == 2 else "f3db99" if index == 3 else "dfedf5"
			part("cyl",Vector3.ZERO,Vector3(1.4,0.22,1.4),hull)
			part("smooth",Vector3(0,0.22,0),Vector3(1.1,0.38,1.1),hull)
			part("hemi",Vector3(0,0.35,0),Vector3(0.65,0.65,0.65),c)
			part("ring",Vector3(0,-0.1,0),Vector3(1.5,0.12,1.5),c)
			for i in (3 if index == 2 else 4 if index == 3 else 6):
				var a := i*TAU/(3 if index == 2 else 4 if index == 3 else 6)
				var at := Vector3(cos(a)*1.45,0,sin(a)*1.45)
				part("box",at,Vector3(0.8,0.15,0.38),hull,Vector3(0,-a,0))
				part("cyl",at+Vector3(0,-0.2,0),Vector3(0.2,0.3,0.2),c)
			if index == 3: part("ring",Vector3(0,0.55,0),Vector3(1.75,0.09,1.75),c)
		5,7:
			part("cyl",Vector3.ZERO,Vector3(0.48,2.2,0.48),"d7e5ee" if index == 5 else "354b66")
			part("point",Vector3(0,1.45,0),Vector3(0.48,0.85,0.48),c)
			part("ring",Vector3(0,0.4,0),Vector3(0.53,0.15,0.53),c)
			for i in 3:
				var a := i*TAU/3
				part("box",Vector3(cos(a)*0.6,-0.7,sin(a)*0.6),Vector3(0.7,0.65,0.1),c,Vector3(0,-a,0))
			part("point",Vector3(0,-1.65,0),Vector3(0.3,1.0,0.3),"82edff",Vector3(PI,0,0))
			if index == 7:
				for x in [-0.7,0.7]:
					part("cyl",Vector3(x,-0.2,0),Vector3(0.2,1.4,0.2),"d7e5ee")
					part("point",Vector3(x,0.65,0),Vector3(0.2,0.4,0.2),c)
		6:
			part("cyl",Vector3.ZERO,Vector3(0.65,1.8,0.65),"fff1df")
			part("point",Vector3(0,1.25,0),Vector3(0.65,0.85,0.65),c)
			part("ball",Vector3(0,0.3,0.62),Vector3(0.3,0.3,0.09),"71d6e9")
			for x in [-1,1]: part("box",Vector3(x*0.7,-0.55,0),Vector3(0.2,0.9,0.75),c,Vector3(0,0,x*-0.35))
			part("point",Vector3(0,-1.3,0),Vector3(0.4,0.9,0.4),"ffcd66",Vector3(PI,0,0))
	return m.bake(parts)
