function updatePreviewsTab() {
  const name = $("#preview-select").val();
  if (!name || !Store.previews[name]) return;

  const container = $("#preview-content");
  container.empty();

  const text = Store.previews[name];

  const html = `
    <div class="preview-editor">

      <div class="preview-toolbar">
        <button id="preview-revert">⟳</button>
        <button id="preview-save">💾</button>
      </div>
      <textarea id="preview-text"
                spellcheck="false"
                class="preview-textarea"
                style="width:100%; height:300px; font-family:monospace; font-size:14px;">${escapeHtml(text).trim()}</textarea>

    </div>
  `;

  container.append(html);

  bindPreviewActions(name);
}

function bindPreviewActions(name) {
  $("#preview-save").on("click", function () {
    Store.previews[name] = $("#preview-text").val();
//    sketchup.savePreview(name, Store.previews[name]);
  });

  $("#preview-revert").on("click", function () {
    if (!Store.defaults.previews[name]) return;
    Store.previews[name] = Store.defaults.previews[name];
    updatePreviewsTab();
  });

  $("#preview-remove").on("click", function () {
    if (!confirm(`Remove preview "${name}" ?`)) return;
    delete Store.previews[name];
//    sketchup.removePreview(name);
    populateSelect("#preview-select", Store.previews);
    updatePreviewsTab();
  });

  $("#preview-add").on("click", function () {
    const newName = prompt("Nom de la nouvelle preview ?");
    if (!newName || Store.previews[newName]) return;

    Store.previews[newName] = "; new preview\n";
    populateSelect("#preview-select", Store.previews);
    $("#preview-select").val(newName).selectmenu("refresh");
    updatePreviewsTab();
  });
}