var obj;
var files;
var apikey;
var dataobject;

const mapDataClipPath = [
  // Homes
  { id: 1, title: "Home X", gShape:"", clipPath: "polygon(3.85% 1.26%, 19.23% 1.26%, 19.23% 5.46%, 6.72% 21.85%, 3.85% 21.85%, 3.85% 1.26%)",color: "rgba(255,0,0,0.8)" ,hoverShift:[-2,-2],spanText:["🏠 X","4%","2%","1.2em"]},
  { id: 2, title: "Home Y", gShape:"", clipPath: "polygon(59.62% 1.26%, 76.28% 1.26%, 76.28% 21.85%, 72.76% 21.85%, 59.62% 5.88%, 59.62% 1.26%)",color: "rgba(255,0,0,0.8)"  ,hoverShift:[2,-2],spanText:["🏠 Y","63%","2%","1.2em"]},
  { id: 3, title: "Home Z", gShape:"", clipPath: "polygon(59.62% 93.7%, 59.62% 96.64%, 76.28% 96.64%, 76.28% 76.05%, 73.72% 76.05%, 59.62% 93.7%)",color: "rgba(255,0,0,0.8)"  ,hoverShift:[2,2],spanText:["🏠 Z","63%","87%","1.2em"]},
  { id: 4, title: "Home",   gShape:"", clipPath: "polygon(3.85% 96.64%, 19.23% 96.64%, 19.23% 93.7%, 6.72% 76.05%, 3.85% 76.05%, 3.85% 1.26%)",color: "rgba(255,0,0,0.8)"  ,hoverShift:[-2,2],spanText:["🏠","4%","87%","1.2em"]},

  // Z+
  { id: 5, title: "Z 100", gShape:"", clipPath: "polygon(83.33% 1.26%, 95.19% 1.26%, 95.19% 14.71%, 83.33% 14.71%, 83.33% 1.26%)",color: "rgba(0,255,0,0.6)" ,hoverShift:[2,-2],spanText:["100","85%","5%","1.2em"]},
  { id: 6, title: "Z 10",  gShape:"", clipPath: "polygon(83.33% 14.71%, 95.19% 14.71%, 95.19% 26.47%, 83.33% 26.47%, 83.33% 14.71%)",color: "rgba(0,212,0,0.6)" ,hoverShift:[2,-2],spanText:["10","87%","20%","1.2em"]},
  { id: 7, title: "Z 1",   gShape:"", clipPath: "polygon(83.33% 26.47%, 95.19% 26.47%, 95.19% 37.0%, 83.33% 37.0%, 83.33% 26.47%)" ,color: "rgba(0,170,0,0.6)",hoverShift:[2,-2],spanText:["1","89%","30%","1.2em"]},
  { id: 8, title: "Z 0.1", gShape:"", clipPath: "polygon(83.33% 37.0%, 95.19% 37.0%, 95.19% 46.54%, 83.33% 46.54%, 83.33% 37.0%)",color: "rgba(0,128,0,0.6)" ,hoverShift:[2,-2],spanText:["0.1","87%","40%","1.2em"]},

  // Z-
  { id: 9, title: "Z -0.1",  gShape:"", clipPath: "polygon(83.33% 50.1%, 95.19% 50.1%, 95.19% 61.34%, 83.33% 61.34%, 83.33% 52.1%)",color: "rgba(0,128,0,0.6)"  ,hoverShift:[2,2]},
  { id: 10, title: "Z -1",   gShape:"", clipPath: "polygon(83.33% 61.34%, 95.19% 61.34%, 95.19% 71.64%, 83.33% 71.64%, 83.33% 61.34%)" ,color: "rgba(0,170,0,0.6)" ,hoverShift:[2,2]},
  { id: 11, title: "Z -10",  gShape:"", clipPath: "polygon(83.33% 71.64%, 95.19% 71.64%, 95.19% 82.77%, 83.33% 82.77%, 83.33% 71.64%)",color: "rgba(0,212,0,0.6)"  ,hoverShift:[2,2]},
  { id: 12, title: "Z -100", gShape:"", clipPath: "polygon(83.33% 82.77%, 95.19% 82.77%, 95.19% 95.59%, 83.33% 95.59%, 83.33% 1.26%)",color: "rgba(0,255,0,0.6)"  ,hoverShift:[2,2]},

  // X+
  { id: 13, title: "X 100", gShape:[40, 50, 30, 38, 320, 400 ], clipPath: "" ,color: "rgba(0,0,255,0.6)",hoverShift:[3,0],spanText:["100","70%","47%","1.2em"]},
  { id: 14, title: "X 10",  gShape:[40, 50, 20, 30, 320, 400 ], clipPath: "" ,color: "rgba(0,0,212,0.6)",hoverShift:[3,0],spanText:["10","62%","47%","1.2em"]},
  { id: 15, title: "X 1",   gShape:[40, 50, 10, 20, 320, 400 ], clipPath: "" ,color: "rgba(0,0,170,0.6)",hoverShift:[3,0],spanText:["1","52%","47%","1.2em"]},
  { id: 16, title: "X 0.1", gShape:[40, 50,  0, 10, 320, 400 ], clipPath: "" ,color: "rgba(0,0,128,0.6)",hoverShift:[3,0],spanText:["0.1","42%","47%","1.2em"]},

  // X-
  { id: 17, title: "X -0.1", gShape:[40, 50,  0, 10, 140, 220], clipPath: "" ,color: "rgba(0,0,128,0.6)" ,hoverShift:[-3,0]},
  { id: 18, title: "X -1",   gShape:[40, 50, 10, 20, 140, 220], clipPath: "" ,color: "rgba(0,0,170,0.6)" ,hoverShift:[-3,0]},
  { id: 19, title: "X -10",  gShape:[40, 50, 20, 30, 140, 220], clipPath: "" ,color: "rgba(0,0,212,0.6)" ,hoverShift:[-3,0]},
  { id: 20, title: "X -100", gShape:[40, 50, 30, 38, 140, 220], clipPath: "" ,color: "rgba(0,0,255,0.6)" ,hoverShift:[-3,0]},

  // Y+
  { id: 21, title: "Y 100", gShape:[40, 50, 30, 38, 225, 315], clipPath: "" ,color: "rgba(255,255,0,0.6)" ,hoverShift:[0,-3]},
  { id: 22, title: "Y 10",  gShape:[40, 50, 20, 30, 225, 315], clipPath: "" ,color: "rgba(212,212,0,0.6)" ,hoverShift:[0,-3]},
  { id: 23, title: "Y 1",   gShape:[40, 50, 10, 20, 225, 315], clipPath: "" ,color: "rgba(170,170,0,0.6)" ,hoverShift:[0,-3]},
  { id: 24, title: "Y 0.1", gShape:[40, 50,  0, 10, 225, 315], clipPath: "" ,color: "rgba(128,128,0,0.6)" ,hoverShift:[0,-3]},

  // Y-
  { id: 25, title: "Y -0.1", gShape:[40, 50,  0, 10, 45, 135], clipPath: "" ,color: "rgba(128,128,0,0.6)" ,hoverShift:[0,3]},
  { id: 26, title: "Y -1",   gShape:[40, 50, 10, 20, 45, 135], clipPath: "" ,color: "rgba(170,170,0,0.6)" ,hoverShift:[0,3]},
  { id: 27, title: "Y -10",  gShape:[40, 50, 20, 30, 45, 135], clipPath: "" ,color: "rgba(212,212,0,0.6)" ,hoverShift:[0,3]},
  { id: 28, title: "Y -100", gShape:[40, 50, 30, 38, 45, 135], clipPath: "" ,color: "rgba(255,255,0,0.6)" ,hoverShift:[0,3]},
];

function generateCShape(cx, cy, rInner, rOuter, startAngle, endAngle, points = 20) {
    const coords = [];
    // contour extérieur
    for (let i = 0; i <= points; i++) {
        const angle = (startAngle + (i / points) * (endAngle - startAngle)) * Math.PI / 180;
        const x = cx + rOuter * Math.cos(angle);
        const y = cy + rOuter * Math.sin(angle);
        coords.push(`${x.toFixed(2)}% ${y.toFixed(2)}%`);
    }
    // contour intérieur (en sens inverse)
    for (let i = points; i >= 0; i--) {
        const angle = (startAngle + (i / points) * (endAngle - startAngle)) * Math.PI / 180;
        const x = cx + rInner * Math.cos(angle);
        const y = cy + rInner * Math.sin(angle);
        coords.push(`${x.toFixed(2)}% ${y.toFixed(2)}%`);
    }
    return `polygon(${coords.join(', ')})`;
}

function httpToWs(url) {
  // Si ça commence par https → convertir en wss
  if (url.startsWith("https://")) {
    return url.replace("https://", "wss://");
  }
  // Si ça commence par http → convertir en ws
  if (url.startsWith("http://")) {
    return url.replace("http://", "ws://");
  }
  // Sinon on considère que c'est déjà une URL WS
  return url;
}

const buttons = document.getElementById("jog-buttons");

$(document).ready(function(){
	$("#XStr").val("0.00");
	$("#YStr").val("0.00");
	$("#ZStr").val("0.00");
	$("#jogSpeed").val("6000");
	$("#SpindleSpeed").val("255");
	mapDataClipPath.forEach((btn, index) => {
	  const area = document.createElement("button");
	  area.classList.add("jog-btn");        // une classe pour style commun
	  area.title = btn.title
	  if (btn.spanText && btn.spanText.length === 4) {
		// texte déplaçable
		const [spantexte,cx,cy,fontsize] = btn.spanText;
		const label = document.createElement("span");
		label.textContent = spantexte;
		label.style.position = "absolute";
		label.style.left = cx;   // X
		label.style.top = cy;    // Y
		label.style.fontSize = fontsize;
		area.appendChild(label);
	  }
	  let clip;
	  if (btn.gShape && btn.gShape.length === 6) {
		const [cx, cy, rInner, rOuter, startAngle, endAngle] = btn.gShape;
		clip = generateCShape(cx, cy, rInner, rOuter, startAngle, endAngle);
	  } else {
		clip = btn.clipPath;   // directement utilisé
	  }
	  area.style.clipPath = clip;
	  area.style.background = btn.color || "rgba(0,150,255,0.6)"; // couleur spécifique ou défaut

	  if (btn.hoverShift && btn.hoverShift.length === 2) {
		const [shiftX, shiftY] = btn.hoverShift;
		area.onmouseenter = () => {
		  area.style.transform = `translate(${shiftX}px,${shiftY}px)`;
		};
	  } else {
		area.onmouseenter = () => {
		  area.style.transform = `translate(-2px,-2px)`;
		};
	  }
	  // pseudo-élément border via style CSS inline
	  area.style.overflow = "visible"; // pour que ::after dépasse si besoin
	  area.onmouseleave = () => {
		area.style.transform = "translate(0px,0px)";
	  };
	  area.onclick = () => buttonClicked(btn.id);
	  area.id = `btn-${btn.id}`; // ID pour cibler le pseudo-élément
	  buttons.appendChild(area);
	});
	setupFiles();
	sketchup.ready();
	updateTabsHeight(); // Initialiser la hauteur correcte des tabs
});
// Mettre à jour la hauteur de #tabs en fonction de la hauteur du footer
function updateTabsHeight() {
	const footerHeight = $('#ui-footer').outerHeight(); // Hauteur du footer
	$('#tabs').css('max-height', 'calc(100vh - ' + footerHeight + 'px)');
}
function formatToTwoDecimals($input) {
  let val = parseFloat($input.val());
  if (!isNaN(val)) {
	$input.val(val.toFixed(2)); // toujours 2 décimales
  }
}

$("#setToCoord" ).on( "click", function( event ) {
	let coords = {
				"X":$("#XStr").val(),
				"Y":$("#YStr").val(),
				"Z":$("#ZStr").val()
				};
	sketchup.buttonPress(33,coords);
});

$("#setToZero" ).on( "click", function( event ) {
	$("#XStr").val("0.00");
	$("#YStr").val("0.00");
	$("#ZStr").val("0.00");
	let coords = {
				"X":0.00,
				"Y":0.00,
				"Z":0.00
				};
	sketchup.buttonPress(33,coords);
});

$("#moveToCoord" ).on( "click", function( event ) {
	let coords = {
				"X":$("#XStr").val(),
				"Y":$("#YStr").val(),
				"Z":$("#ZStr").val(),
				"F":$("#jogSpeed").val()
				};
	
	console.log($("#useDefaultSpeed").is(":checked"))
	if ($('#useDefaultSpeed').is(":checked")) {
		coords = {
				"X":$("#XStr").val(),
				"Y":$("#YStr").val(),
				"Z":$("#ZStr").val()
				};
	}
	sketchup.buttonPress(47,coords);
});

$("#SpindleSpeed").change(function() {
  let val = parseInt($(this).val(), 10); // convertir en entier
  if (val > 255) {
	$(this).val(255);
  } else if (val < 0) {
	$(this).val(0);
  } else {
	$(this).val(val);
  }
});

$("#spindleStart1" ).on( "click", function( event ) {
	let val = {
				"speed":parseInt($("#SpindleSpeed").val(),10)
			  };
	sketchup.buttonPress(34,val);
});

$("#spindleStart2" ).on( "click", function( event ) {
	let val = {
				"speed":parseInt($("#SpindleSpeed").val(),10)
			  };
	sketchup.buttonPress(35,val);
});

$("#spindleStop" ).on( "click", function( event ) {
	sketchup.buttonPress(36,0);
});

$("#MesureMode" ).on( "click", function( event ) {
    const btn = $(this);
	let milimetre;
    if (btn.text() === "Millimetre") {
	  milimetre = false;
      btn.text("Pouce");
    } else {
	  milimetre = true;
      btn.text("Millimetre");
    }
	sketchup.buttonPress(37,milimetre);
});

$("#MovementStyle" ).on( "click", function( event ) {
    const btn = $(this);
	let relatif;
    if (btn.text() === "Relatif") {
	  relatif = false;
      btn.text("Absolu");
    } else {
	  relatif = true;
      btn.text("Relatif");
    }
	sketchup.buttonPress(38,relatif);
});

// Sur blur (quand on sort du champ)
$("#XStr, #YStr, #ZStr").on("blur", function() {
  formatToTwoDecimals($(this));
});

$("#tabs").tabs();
$("#tabs").find("li:eq(0)").hide(); // cache le 1er onglet
$("#tabs").find("li:eq(1)").hide(); // cache le 2e onglet
$("#tabs").find("li:eq(2)").hide(); // cache le 3e onglet
$("#tabs").find("li:eq(3)").hide(); // cache le 4e onglet
$("#tabs").tabs("option", "active", 4); // ouvre l’onglet 5

$( "#setDefault, #cancel, #accept").button();

$( "#setDefault" ).on( "click", function( event ) {
	obj.api_key = $("#api_key").val();
	obj.host = $("#host").val();
	obj.macro1 = $("#Macro1Input").val();
	obj.macro2 = $("#Macro2Input").val();
	obj.macro3 = $("#Macro3Input").val();
	sketchup.setDefault(obj);
});

$( "#accept" ).on( "click", function( event ) {
	obj.api_key = $("#api_key").val();
	obj.host = $("#host").val();
	obj.macro1 = $("#Macro1Input").val();
	obj.macro2 = $("#Macro2Input").val();
	obj.macro3 = $("#Macro3Input").val();
	sketchup.accept(obj);
});

$( "#cancel" ).on( "click", function( event ) {
	sketchup.cancel();
});

$("#host").change(function(){
  obj.host = $("#host").val();
  sketchup.newValue("host",obj);
}); 

$( "#send" ).on( "click", function( event ) {
	sketchup.buttonPress(30,$("#sendStr").val());
});

$("#Macro1Input").change(function(){
  obj.macro1 = $("#Macro1Input").val();
  sketchup.newValue("Macro1button",obj);
});
 
$("#Macro2Input").change(function(){
  obj.macro2 = $("#Macro2Input").val();
  sketchup.newValue("Macro2button",obj);
});
 
$("#Macro3Input").change(function(){
  obj.macro3 = $("#Macro1Input").val();
  sketchup.newValue("Macro3button",obj);
}); 


$(".macro-btn").on("click", function () {
  const target = $(this).data("target");     // lit l’attribut data-target
  const value = $(target).val();             // récupère la valeur de l’input lié
  sketchup.buttonPress(30, value);
});

$("#api_key").change(function(){
  obj.api_key = $("#api_key").val();
  sketchup.newValue("api_key",obj);
}); 

function buttonClicked(buttonNo) {
	let val = {
				"speed":$("#jogSpeed").val()
			  };
	sketchup.buttonPress(buttonNo,val);
};

function update_position(data) {
	$("#XStr, #YStr, #ZStr").on("blur", function() {
  formatToTwoDecimals($(this));
})
	$("#XStr").val("0.00");
	$("#YStr").val("0.00");
	$("#ZStr").val("0.00");	
}

function statusDialog(datadialog) {
	var objdata =  JSON.parse(datadialog);
	let text = "";
	// ping
	text += "Host: " + (objdata.ping ? "disponible" : "non disponible") + "<br>";

	// current.* infos
	if (objdata.current) {
		text += "État: " + objdata.current.state + "<br>";
		text += "Baudrate: " + objdata.current.baudrate + "<br>";
		text += "Port: " + objdata.current.port + "<br>";
		text += "Profile: " + objdata.current.printerProfile + "<br>";
		if (objdata.current.state === "Closed") {
			text += '<button id="auto_connect_btn">Auto Connect</button>';
		} else {
			text += '<button id="disconnect_btn">Disconnect</button>';
		}
	}

	// mettre dans #host_available
	$("#host_available").html(text);
	$("#auto_connect_btn").on("click", function () {
	  sketchup.buttonPress(31,$("#sendStr").val());
	});
	$("#disconnect_btn").on("click", function () {
	  sketchup.buttonPress(32,$("#sendStr").val());
	});		
};

function  updateDialog(datajson) {
	obj =  JSON.parse(datajson);
	$("#host").val(obj.host);
	$("#api_key").val(obj.api_key);
	if (obj.ping) {
	  $("#tabs").find("li:eq(0)").show(); // cache le 1er onglet
	  $("#tabs").find("li:eq(1)").show(); // cache le 2e onglet
	  $("#tabs").find("li:eq(2)").show(); // cache le 3e onglet
	  $("#tabs").find("li:eq(3)").show(); // cache le 4e onglet
	} else {
	  $("#tabs").find("li:eq(0)").hide(); // cache le 1er onglet
	  $("#tabs").find("li:eq(1)").hide(); // cache le 2e onglet
	  $("#tabs").find("li:eq(2)").hide(); // cache le 3e onglet
	  $("#tabs").find("li:eq(3)").hide(); // cache le 4e onglet
	  $("#tabs").tabs("option", "active", 4); // ouvre l’onglet 5
	}
	$("#Macro1Input").val(obj.macro1);
	$("#Macro2Input").val(obj.macro2);
	$("#Macro3Input").val(obj.macro3);	
};

function  updateObjects(dataobjectjson) {
	dataobject =  JSON.parse(dataobjectjson);
	let objectList = document.getElementById("objectList");
	objectList.innerHTML = ""; // vider le contenu précédent
	if (!dataobject || dataobject.length === 0) {
		objectList.innerHTML = "<p>Aucun objet trouvé</p>";
		return;
	}
	let div = document.createElement("div");
	div.id = "object-container"; // <-- affecte l'ID
	// Création d'une liste UL (liste non ordonnée) qui contiendra tous les fichiers
	let ul = document.createElement("ul");
	ul.style.listStyleType = "none"
	console.log(dataobject.objet)
	dataobject.objet.forEach(objectx => {
		console.log(objectx)
		let btnGroup = document.createElement("div");
		btnGroup.classList.add("spindlecontainer");
		// Création d’un élément <li> (un élément de la liste)
		let li = document.createElement("li");
		li.innerHTML = objectx.name
		btnGroup.appendChild(li);
		// --- Bouton "Imprimer"
		let btnPrint = document.createElement("button");
		btnPrint.textContent = "🖨️";
		btnPrint.title = "Impression";
		btnPrint.addEventListener("click", async () => {
			sketchup.buttonPress(39,objectx);
		});
		btnGroup.appendChild(btnPrint);
		// --- Bouton "Envoie a l editeur"
		let btnSendToText = document.createElement("button");
		btnSendToText.textContent = "💾";
		btnSendToText.title = "Envoie a l editeur";
		btnSendToText.addEventListener("click", async () => {
			sketchup.buttonPress(48,objectx);
		});
		btnGroup.appendChild(btnSendToText);
		ul.appendChild(btnGroup);
	});
	div.appendChild(ul)
	objectList.appendChild(div);
};

function  updateFiles(datafilejson) {
	files =  JSON.parse(datafilejson);
	let fileDiv = document.getElementById("filediv");
	fileDiv.innerHTML = ""; // vider le contenu précédent

	if (!files || files.length === 0) {
		fileDiv.innerHTML = "<p>Aucun fichier trouvé</p>";
		return;
	}
	let div = document.createElement("div");
	div.id = "file-container"; // <-- affecte l'ID
	// Création d'une liste UL (liste non ordonnée) qui contiendra tous les fichiers
	let ul = document.createElement("ul");
	
	// On parcourt le tableau `files` (retourné par OctoPrint via l’API REST)
	files.forEach(file => {
		// Création d’un élément <li> (un élément de la liste)
		let li = document.createElement("li");
		
		// Création d’un lien <a> pour représenter le fichier
		let link = document.createElement("a");
		link.textContent = file.name;	 // le texte affiché = nom du fichier
		link.href = "#"; // on met un href factice, car on va gérer le clic nous-mêmes
		
		// on agrandit le texte en ligne
		link.style.fontSize = "1.5em";   // 40% plus gros
		link.style.fontWeight = "bold";  // en gras
		
		link.addEventListener("click", async (e) => {
			e.preventDefault();		// empêche le comportement par défaut du lien (navigation)
			sketchup.buttonPress(40,file);
		});
		
		li.appendChild(link);
		// Groupe de boutons sous le nom
		let btnGroup = document.createElement("div");
		btnGroup.classList.add("button-group");	
		
		// --- Bouton "Télécharger"
		let btnDownload = document.createElement("button");
		btnDownload.textContent = "⬇️";
		btnDownload.title = "Télécharger le fichier";
		btnDownload.addEventListener("click", async (e) => {
			sketchup.buttonPress(40,file);
		});

		btnGroup.appendChild(btnDownload);


		// --- Bouton "Imprimer"
		let btnPrint = document.createElement("button");
		btnPrint.textContent = "🖨️";
		btnPrint.title = "Impression";
		btnPrint.addEventListener("click", async (e) => {
			sketchup.buttonPress(44,file);
		});

		btnGroup.appendChild(btnPrint);


		
		// --- Bouton "Pause / Resume"
		let btnPauseResume = document.createElement("button");
		btnPauseResume.textContent = "⏯️"; // play/pause icon
		btnPauseResume.title = "Pause / Reprendre l'impression";
		btnPauseResume.addEventListener("click", async (e) => {
			sketchup.buttonPress(42,file);
		});

		btnGroup.appendChild(btnPauseResume);

		// --- Bouton "Cancel"
		let btnCancel = document.createElement("button");
		btnCancel.textContent = "❌";
		btnCancel.title = "Annuler l'impression";
		btnCancel.addEventListener("click", async (e) => {
			sketchup.buttonPress(43,file);
		});
		
		btnGroup.appendChild(btnCancel);

		// --- Bouton "Supprimer"
		let btnDelete = document.createElement("button");
		btnDelete.textContent = "🗑️";
		btnDelete.title = "effacer fichier";
		btnDelete.addEventListener("click", async (e) => {
			sketchup.buttonPress(45,file);
		});

		btnGroup.appendChild(btnDelete);
		li.appendChild(btnGroup);
		ul.appendChild(li);
	});
	div.appendChild(ul)
	fileDiv.appendChild(div);
};


function  setupFiles() {	
	let dropZone = document.getElementById("dropZone");
	let fileInput = document.getElementById("fileInput");
	let uploadLocation = document.getElementById("uploadLocation");
	let progressContainer = document.getElementById("progressContainer");
	let uploadProgress = document.getElementById("uploadProgress");
	let progressText = document.getElementById("progressText");

	// Clique → ouvrir le sélecteur fichier
	dropZone.addEventListener("click", () => fileInput.click());

	// Drag & Drop
	dropZone.addEventListener('dragover', e => {
	  e.preventDefault();
	  dropZone.style.background = "#eef";
	});
	dropZone.addEventListener('dragleave', e => {
	  e.preventDefault();
	  dropZone.style.background = "";
	});
	dropZone.addEventListener('drop', e => {
	  e.preventDefault();
	  dropZone.style.background = "";
	  if(e.dataTransfer.files.length > 0) {
		uploadFile(e.dataTransfer.files[0]);
	  }
	});

	// Si choisi par clic
	fileInput.addEventListener("change", () => {
	  if (fileInput.files.length > 0) {
		console.log(fileInput.files[0])
		uploadFile(fileInput.files[0]);
	  }
	});
};

// Fonction d’upload avec progression
function uploadFile(file) {
  console.log(file.name)
  const reader = new FileReader();
  reader.onload = function(e) {
	const content = e.target.result;

	objet = {}
	objet["filename"] = file.name
	objet["content"] = content
	sketchup.buttonPress(46,objet);
	document.getElementById("fileInput").value = "";
//		$("#fileContent").text(content); // Affiche le contenu du fichier
  };

  reader.readAsText(file); // Lit le fichier comme texte
};


const editor = document.getElementById("editor");
const lineNumbers = document.getElementById("line-numbers");

let currentFileName = null; // pour tracking du fichier actuel


function updateLineNumbers() {
  const lines = editor.value.split("\n").length;
  let numbers = "";
  for (let i = 1; i <= lines; i++) numbers += i + "\n";
  lineNumbers.textContent = numbers;
}

// Scroll synchronisé
editor.addEventListener("scroll", () => {
  lineNumbers.scrollTop = editor.scrollTop;
});

// Tabulation
editor.addEventListener("keydown", e => {
  if (e.key === "Tab") {
    e.preventDefault();
    const start = editor.selectionStart;
    const end = editor.selectionEnd;
    editor.value = editor.value.substring(0, start) + "  " + editor.value.substring(end);
    editor.selectionStart = editor.selectionEnd = start + 2;
    updateLineNumbers();
  }
});

editor.addEventListener("input", updateLineNumbers);
updateLineNumbers();

// 🔹 Bouton “Ouvrir fichier”
document.getElementById("openButton").addEventListener("click", () => {
	sketchup.loadText(currentFileName); // hook Ruby
});

// Met à jour l'affichage du nom du fichier
function updateFilenameDisplay(setFileName) {
  if (setFileName != "") {
      currentFileName = setFileName
  }
  document.getElementById("filename-display").textContent = currentFileName || "Aucun fichier ouvert";
}

function loadEditor(filename,content) {
	if (content != null) {
      editor.value = content;
      updateLineNumbers();
      currentFileName = filename;
	  updateFilenameDisplay(currentFileName)
	} else {
	  currentFileName = "";
	  updateFilenameDisplay(currentFileName)
    }
};

document.getElementById("saveButton").addEventListener("click", () => {
  if (!currentFileName) {
	currentFileName = "undefined"
  }
  sketchup.saveText(currentFileName, editor.value,false); // hook Ruby
});

document.getElementById("saveAsButton").addEventListener("click", () => {
  if (!currentFileName) {
	currentFileName = "undefined"
  }
  sketchup.saveText(currentFileName, editor.value,true); // hook Ruby
});

document.getElementById("newButton").addEventListener("click", () => {
  currentFileName = null
  editor.value = "";
  updateFilenameDisplay(currentFileName)
});

// 🔹 Exécuter : sélection ou tout
document.getElementById("runButton").addEventListener("click", () => {
  const selection = editor.value.substring(editor.selectionStart, editor.selectionEnd);
  const codeToRun = selection || editor.value;
  let val = {
			  "code":codeToRun
			};
  sketchup.buttonPress(50,val);
});

$('#useG2Code').on('change', function() {
  if ($(this).is(':checked')) {
	sketchup.buttonPress(49,true);
  } else {
	sketchup.buttonPress(49,false);
  }
});

updateLineNumbers();