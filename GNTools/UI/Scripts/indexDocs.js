////////////////////////////////////////////////////////////////////////////////
// Données du projet
////////////////////////////////////////////////////////////////////////////////

let jsonData = {};
let rootPath = "";    // Le chemin défini comme racine virtuelle
let selectedNode = null;
let rootDirHandle = null;

$(document).ready(function() {
  sketchup.ready();
});

// Définir racine
function defineRoot(path) {
    window.sketchup.defineRoot(path); // Appelle le callback Ruby
}

// Ajouter un dossier
function addFolder(folderName) {
    if (!folderName) return;
    window.sketchup.addFolder(folderName); // Appelle le callback Ruby
}

// Bouton "Définir racine"
$("#btnSetRoot").click(() => {
	sketchup.chooseRoot();
});

// ouverture du dialog
$("#btnAddFolder").click(() => {
	sketchup.addFolder()
});

function receiveRubyParse(data) {
    console.log("Reçu depuis Ruby parse:", data);
    jsonData = data;
	rebuildTree();
}

////////////////////////////////////////////////////////////////////////////////
// Chargement JSON
////////////////////////////////////////////////////////////////////////////////

$("#importJSON").click(() => $("#fileInputJSON").click());

$("#fileInputJSON").change(function(e){
    const reader = new FileReader();
    reader.onload = evt => {
        jsonData = JSON.parse(evt.target.result);
        rebuildTree();
    };
    reader.readAsText(e.target.files[0]);
});


////////////////////////////////////////////////////////////////////////////////
// Export JSON
////////////////////////////////////////////////////////////////////////////////

$("#saveJSON").click(() => {
    const dataStr = "data:text/json;charset=utf-8," +
        encodeURIComponent(JSON.stringify(jsonData, null, 2));
    const a = document.createElement("a");
    a.href = dataStr;
    a.download = "documentation.json";
    a.click();
});

////////////////////////////////////////////////////////////////////////////////
// Ajouter un fichier Ruby
////////////////////////////////////////////////////////////////////////////////

$("#addFile").click(() => {
	sketchup.chooseFile();
});

////////////////////////////////////////////////////////////////////////////////
// Construire jsTree
////////////////////////////////////////////////////////////////////////////////

function convertToJsTree(tree, parentPath = "") {
    return Object.keys(tree).map(key => {
        const value = tree[key];
        const fullPath = parentPath ? `${parentPath}/${value.name}` : value.name;

        // --- Détection du type ---
        const type = (value && typeof value === "object" && value.type) ? value.type : "dir";

        // --- Choix des icônes selon le type ---
        let icon = "jstree-folder";  // défaut

        switch (type) {
            case "file":
                icon = "fa-solid fa-file";
                break;
            case "module":
                icon = "fa-solid fa-cube";
                break;
            case "class":
                icon = "fa-solid fa-cubes";
                break;
            case "method":
                icon = "fa-solid fa-code";
                break;
            case "dir":
            default:
                icon = "fa-solid fa-folder";
        }

        return {
            id: fullPath,
            text: value.name,
            icon: icon,
            data: value,
			children: value.children ? convertToJsTree(value.children, fullPath) : []
        };
    });
}

function rebuildTree() {
    $("#jstree").jstree("destroy");

    $("#jstree").jstree({
        core: {
            data: convertToJsTree(jsonData)
        }
    });

    $("#jstree").on("select_node.jstree", function(e, obj){
        selectedNode = obj.node;
        const info = selectedNode.data || {};

		console.log(selectedNode)

        $("#nodeTitle").text(selectedNode.text);
        $("#description").val(info.description || "");
    });
}

rebuildTree();


////////////////////////////////////////////////////////////////////////////////
// Sauvegarde de la description
////////////////////////////////////////////////////////////////////////////////

$("#saveDesc").click(() => {
    if (!selectedNode) return;
	console.log(selectedNode.data.name)
	console.log(selectedNode.data.description)
	selectedNode.data.description = $("#description").val();
    alert("Sauvegardé !");
});