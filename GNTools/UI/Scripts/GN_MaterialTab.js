function updateMaterialTab() {
	
}

function updateMaterial(datajson) {
	console.log(datajson)
	objMaterial = JSON.parse(datajson);
	$( "#safeHeight" ).spinner( "value", objMaterial.safeHeight );
	$( "#Depth" ).val(objMaterial.depth);
	$( "#Thickness" ).val(objMaterial.height);
	$( "#Width" ).val(objMaterial.width);
	$( "#material_type" ).val(objMaterial.material_type);
	$( "#material_type" ).selectmenu("refresh");
}

$(function() {
	$("#material_type").selectmenu();	
	$("#safeHeight").spinner();
	$("#Depth").spinner();
	$("#Thickness").spinner();
	$("#Width").spinner();
});