extends SceneTree
## Compile generated albedo into periodic, native-resolution zoom materials.
## Masters are preserved. Processing is offline; runtime never resizes images.
const MATERIALS := ["grass","forest","rock","snow"]
const TIERS := {100:192,200:384,400:768,600:1024,800:1254}
const ROOT := "res://assets/map/materials/"

func _initialize() -> void: call_deferred("run")

func configure_import(path: String) -> void:
    var config := ConfigFile.new()
    config.load(path+".import")
    config.set_value("remap","importer","texture")
    config.set_value("remap","type","CompressedTexture2D")
    config.set_value("deps","source_file",path)
    config.set_value("params","compress/mode",0)
    config.set_value("params","mipmaps/generate",true)
    assert(config.save(path+".import")==OK)

func periodic(source: Image) -> Image:
    var result := source.duplicate() as Image
    result.convert(Image.FORMAT_RGB8)
    var w := result.get_width()
    var h := result.get_height()
    var band := int(mini(w,h)*0.06)
    for y in h:
        for x in band:
            var a := result.get_pixel(x,y)
            var b := result.get_pixel(w-1-x,y)
            var mean := (a+b)*0.5
            var weight := smoothstep(0.0,float(band),float(x))
            result.set_pixel(x,y,mean.lerp(a,weight))
            result.set_pixel(w-1-x,y,mean.lerp(b,weight))
    for x in w:
        for y in band:
            var a := result.get_pixel(x,y)
            var b := result.get_pixel(x,h-1-y)
            var mean := (a+b)*0.5
            var weight := smoothstep(0.0,float(band),float(y))
            result.set_pixel(x,y,mean.lerp(a,weight))
            result.set_pixel(x,h-1-y,mean.lerp(b,weight))
    return result

func run() -> void:
    var manifest := {"generator":"built-in image_gen; offline Godot material compiler", "tiling_world":24.0,"tiers":{},"materials":MATERIALS,"sources":{}}
    for percent in TIERS: manifest.tiers[str(percent)]={"size":TIERS[percent],"albedo":{},"normal":{}}
    for material in MATERIALS:
        var source := Image.load_from_file(ROOT+"source/"+material+".png")
        assert(source!=null)
        var master := periodic(source)
        manifest.sources[material]={"path":ROOT+"source/"+material+".png","size":source.get_width(),"sha256":FileAccess.get_sha256(ROOT+"source/"+material+".png")}
        for percent in TIERS:
            var image := master.duplicate() as Image
            var size: int = TIERS[percent]
            image.resize(size,size,Image.INTERPOLATE_LANCZOS)
            var path: String = ROOT+"zoom/"+material+"_"+str(percent)+".png"
            assert(image.save_png(path)==OK)
            configure_import(path)
            manifest.tiers[str(percent)].albedo[material]=path
            var normal := image.duplicate() as Image
            normal.bump_map_to_normal_map(0.65 if material!="snow" else 0.15)
            var normal_path: String = ROOT+"zoom/"+material+"_"+str(percent)+"_normal.png"
            assert(normal.save_png(normal_path)==OK)
            configure_import(normal_path)
            manifest.tiers[str(percent)].normal[material]=normal_path
        print("Zoom material compiled: ",material)
    FileAccess.open(ROOT+"manifest.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"  "))
    quit()
