extends RefCounted

const NAMES = ["Trinh sát bạc", "Đĩa sao Thổ", "Ong máy", "Robot phản lực", "Mèo vũ trụ", "Cá voi bay", "Tên lửa kẹo", "Phượng hoàng"]
const COLORS = ["77e6dc","b09aff","ffd15c","7cbcff","ff9bbf","78dbe8","ff8974","ffb34c"]
var m
var parts: Array = []

func part(shape: String, pos: Vector3, scale: Vector3, color: String, rot := Vector3.ZERO) -> void:
	parts.append(m.piece(shape,pos,scale,Color(color),rot))

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
		2:
			part("smooth",Vector3.ZERO,Vector3(0.8,0.65,1.2),c)
			for z in [-0.4,0.3]: part("ring",Vector3(0,0,z),Vector3(0.78,0.12,0.65),"263347",Vector3(PI/2,0,0))
			for x in [-1,1]:
				part("smooth",Vector3(x*1.0,0.45,0),Vector3(0.9,0.09,0.55),"d9f9ff",Vector3(0,0,x*0.2))
				part("ball",Vector3(x*0.29,0.15,1),Vector3.ONE*0.16,"203147")
		3,4:
			part("box" if index == 3 else "smooth",Vector3(0,0.1,0),Vector3(1.2,1.15,0.85) if index == 3 else Vector3(0.6,0.65,0.5),c)
			part("box" if index == 3 else "smooth",Vector3(0,1,0),Vector3(1.35,0.85,0.95) if index == 3 else Vector3(0.75,0.55,0.58),"dcebf6" if index == 3 else "ffe3cb")
			for x in [-1,1]:
				part("ball",Vector3(x*0.3,1.05,0.55),Vector3(0.12,0.17,0.08),"243e59")
				part("cyl",Vector3(x*0.88,0,0),Vector3(0.25,0.75,0.25),"52677f")
				part("point",Vector3(x*0.88,-0.65,0),Vector3(0.2,0.65,0.2),"7eefff",Vector3(PI,0,0))
				if index == 4: part("point",Vector3(x*0.46,1.55,0),Vector3(0.3,0.6,0.25),c)
			part("box",Vector3(0,0.15,0.45),Vector3(0.5,0.25,0.08),"fff0a2")
		5:
			part("smooth",Vector3.ZERO,Vector3(0.95,0.75,1.55),c)
			part("smooth",Vector3(0,-0.25,0.3),Vector3(0.82,0.48,1.15),"e9faff")
			for x in [-1,1]:
				part("smooth",Vector3(x*0.95,-0.1,0),Vector3(0.65,0.12,0.45),"639bd0",Vector3(0,0,x*0.3))
				part("smooth",Vector3(x*0.5,0.1,-1.5),Vector3(0.7,0.13,0.4),c)
				part("ball",Vector3(x*0.65,0.15,1),Vector3.ONE*0.12,"25394e")
		6:
			part("cyl",Vector3.ZERO,Vector3(0.65,1.8,0.65),"fff1df")
			part("point",Vector3(0,1.25,0),Vector3(0.65,0.85,0.65),c)
			part("ball",Vector3(0,0.3,0.62),Vector3(0.3,0.3,0.09),"71d6e9")
			for x in [-1,1]: part("box",Vector3(x*0.7,-0.55,0),Vector3(0.2,0.9,0.75),c,Vector3(0,0,x*-0.35))
			part("point",Vector3(0,-1.3,0),Vector3(0.4,0.9,0.4),"ffcd66",Vector3(PI,0,0))
		7:
			part("smooth",Vector3.ZERO,Vector3(0.55,0.55,1.1),"ff854e")
			part("ball",Vector3(0,0.45,0.85),Vector3.ONE*0.5,c)
			part("point",Vector3(0,0.4,1.42),Vector3(0.22,0.45,0.22),"ffe7a0",Vector3(PI/2,0,0))
			for x in [-1,1]:
				for i in 3: part("smooth",Vector3(x*(0.75+i*0.4),0.12+i*0.15,-i*0.22),Vector3(0.65,0.1,0.6),c if i%2==0 else "ff704c",Vector3(0,x*0.3,x*0.2))
			part("point",Vector3(0,-0.15,-1.25),Vector3(0.45,1.1,0.3),"ffcf68",Vector3(-PI/2,0,0))
	return m.bake(parts)
