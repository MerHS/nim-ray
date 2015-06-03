all: ray.nim objects/rayobj.nim
	nim c ray

release:
	nim c -d:release ray

run:
	./ray
