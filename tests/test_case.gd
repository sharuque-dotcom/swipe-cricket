class_name TestCase
extends RefCounted

var failures: Array[String] = []
var checks := 0

func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)

func near(a: float, b: float, tol: float, msg: String) -> void:
	check(absf(a - b) <= tol, "%s (got %.4f, wanted %.4f +/- %.4f)" % [msg, a, b, tol])
