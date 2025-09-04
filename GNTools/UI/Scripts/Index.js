function generateGCode() {
    // Get user inputs and generate G-code
    var feedrate = document.getElementById("feedrate").value;
    var depth = document.getElementById("depth").value;
    var gcodetext = `G0 X0 Y0 Z0\nG1 F${feedrate} Z-${depth}\n...`;
    setlongText(gcodetext);
}


var recev_gcodetext;
function setlongText(_gcodetext) {
    var container = document.getElementById("longText");
    document.getElementById("longText").textContent = "";
    // Split the text into an array of lines based on the newline character "\n"
    var lines =  _gcodetext.split("\\n");
    recev_gcodetext = _gcodetext;

    // Loop through each line and create a <div> element for it
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        //          Create a new <div> element
        var div = document.createElement("div");

        // Set the content of the <div> to the current line of text
        div.textContent = line;

        // Append the <div> to the container
        container.appendChild(div);
    }
    // Display generated G-code
    setAllLines();
}

function clearFields() {
    // Clear input fields and generated G-code
    document.getElementById("feedrate").value = "";
    document.getElementById("depth").value = "";
    document.getElementById("longText").textContent = "";
}

function cancelDialog() {
    // Close the dialog when the "Cancel" button is clicked
    window.close();
}
function setAllLines() {
    // Get all the div elements within the contenteditable div
    var divElements = document.querySelectorAll("#longText div");

    // Add click event listeners to each div element
    divElements.forEach(function(div) {
        div.addEventListener("click", function() {
            // Remove the "selected" class from all div elements
            divElements.forEach(function(el) {
                el.classList.remove("selected");
            });

            // Add the "selected" class to the clicked div element
            this.classList.add("selected");
        });
    });
}
setAllLines();
