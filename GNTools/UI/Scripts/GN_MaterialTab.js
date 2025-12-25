function updateMaterialTab() {
	
}

function updateMaterial(datajson) {
	objMaterial = datajson;
	$( "#safeHeight" ).cncInputs("value", objMaterial.safeHeight);
	$( "#Depth" ).cncInputs("value", objMaterial.depth);
	$( "#Thickness" ).cncInputs("value", objMaterial.height);
	$( "#Width" ).cncInputs("value", objMaterial.width);
	$( "#material_type" ).val(objMaterial.material_type);
	$( "#material_type" ).selectmenu("refresh");
}

$(function() {
	$("#material_type").selectmenu();
	$("#safeHeight").cncInputs({
	  min: 0,
	  max: 300,
	  step: 0.001,
	  value: 0,

	  units: "mm",
	  dangerZone: { min: 0, max: 25 },
	  snap: true,
	  wheel: true,
	  precisionStep: true,
	  number : true
	});
	$("#Depth").cncInputs({
	  min: 0,
	  max: 500,
	  step: 0.001,
	  value: 0,

	  units: "mm",
	  dangerZone: { min: 0, max: 2 },
	  snap: true,
	  wheel: true,
	  precisionStep: true,
	  number : true,
	  readonly : true
	});
	$("#Thickness").cncInputs({
	  min: 0,
	  max: 500,
	  step: 0.001,
	  value: 0,

	  units: "mm",
	  dangerZone: { min: 0, max: 2 },
	  snap: true,
	  wheel: true,
	  precisionStep: true,
	  number : true,
	  readonly : true
	});
	$("#Width").cncInputs({
	  min: 0,
	  max: 500,
	  step: 0.001,
	  value: 0,
	  units: "mm",
	  dangerZone: { min: 0, max: 2},
	  snap: true,
	  wheel: true,
	  precisionStep: true,
	  number : true,
	  readonly : true
	});
});