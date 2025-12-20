let jsonData = {};
let selectedNodeRef = null;

// Import JSON
document.getElementById('fileInput').addEventListener('change', function(e){
    const reader = new FileReader();
    reader.onload = function(event) {
        jsonData = JSON.parse(event.target.result);
		console.log(jsonData)
        buildTree();
    };
    reader.readAsText(e.target.files[0]);
});

// Convert JSON en structure jsTree
function buildTreeData(obj, path = "") {
    const result = [];

    for (const name in obj) {
        const fullPath = path + "/" + name;
        const data = obj[name];
        if (name.endsWith(".rb")) {
            // Fichier .rb
			


            const fileNode = {
                id: fullPath,
                text: "📄 " + name,
                type: "file",
                data: data,
                children: []
            };

			if (data.Classes) {
				if (data.Classes.length > 0) {
				  if (data.Classes) {
				    const children = [];
					data.Classes.forEach(sub => {
						children.push({
							id: path + "/class:" + sub.Name,
							text: "📗 " + sub.Name,
							type: "class",
							data: sub,
							children: buildClassChildren(sub, path)
						});
					});
					fileNode.children.push(children)
				  }
//				  fileNode.children.push(buildClassChildren(data, fullPath));
				}
			}


            // Modules
            if (data.Modules) {
				if (data.Modules.length > 0) {
					data.Modules.forEach(mod => {
						const modname = mod.Name || mod.name;
						fileNode.children.push({
							id: fullPath + "/module:" + modname,
							text: "📦 " + modname,
							type: "module",
							data: mod,
							children: buildModuleChildren(mod, fullPath)
						});
					});
				}
            }

            result.push(fileNode);

        } else {
            // Dossier
            result.push({
                id: fullPath,
                text: "📁 " + name,
                type: "folder",
                children: buildTreeData(data, fullPath)
            });
        }
    }

    return result;
}

// Sous-nodes Modules → Classes
function buildModuleChildren(moduleObj, path) {
    const children = [];
    if (moduleObj.Classes) {
        moduleObj.Classes.forEach(cls => {
            children.push({
                id: path + "/class:" + cls.Name,
                text: "📘 " + cls.Name,
                type: "class",
                data: cls,
                children: buildClassChildren(cls, path)
            });
        });
    }
    return children;
}

// Sous-nodes classes récursives
function buildClassChildren(cls, path) {
    const children = [];
    if (cls.Classes) {
        cls.Classes.forEach(sub => {
            children.push({
                id: path + "/class:" + sub.Name,
                text: "📗 " + sub.Name,
                type: "class",
                data: sub,
                children: buildClassChildren(sub, path)
            });
        });
    }
    return children;
}

function buildTree() {
    const treeData = buildTreeData(jsonData);

    $('#tree').jstree("destroy"); // Reset
    $('#tree').jstree({
        "core": {
            "data": treeData,
            "multiple": false
        }
    });

    // Sélection
    $('#tree').on("select_node.jstree", function (e, data) {
        selectedNodeRef = data.node.original;
        document.getElementById('title').textContent = data.node.text;
		if (selectedNodeRef.Description) {
			document.getElementById('description').value = selectedNodeRef.Description;
		} else {
			document.getElementById('description').value = "";
		}
    });
}

// Sauvegarde de description
function saveDescription() {
    if (selectedNodeRef) {
        selectedNodeRef.Description = document.getElementById('description').value;
        alert("Description sauvegardée !");
    }
}

// Export JSON
function exportJSON() {
    const dataStr = "data:text/json;charset=utf-8," +
        encodeURIComponent(JSON.stringify(jsonData, null, 2));
    const dl = document.createElement('a');
    dl.href = dataStr;
    dl.download = "documentation.json";
    dl.click();
}

