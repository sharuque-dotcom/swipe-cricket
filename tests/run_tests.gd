extends SceneTree
## Headless test runner:  godot --headless -s tests/run_tests.gd

func _init() -> void:
	var failed := 0
	var total := 0
	var dir := DirAccess.open("res://tests")
	var files := Array(dir.get_files())
	files.sort()
	for f: String in files:
		if not (f.begins_with("test_") and f.ends_with(".gd")) or f == "test_case.gd":
			continue
		var script: GDScript = load("res://tests/" + f)
		for m in script.get_script_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			var t: TestCase = script.new()
			t.call(name)
			total += 1
			if t.failures.is_empty():
				print("  ok    %s::%s (%d checks)" % [f, name, t.checks])
			else:
				failed += 1
				print("  FAIL  %s::%s" % [f, name])
				for msg in t.failures:
					print("          " + msg)
	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 else 0)
