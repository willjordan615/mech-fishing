@tool
extends EditorScenePostImport
 
func _post_import(scene):
	_fix_empty_names(scene, 0)
	return scene
 
func _fix_empty_names(node, index):
	if node.name == "" or node.name == null:
		node.name = "Node_%d" % index
	index += 1
	for child in node.get_children():
		index = _fix_empty_names(child, index)
	return index
 
