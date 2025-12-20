var drillBits = [];


window.addRowToTable = function(datajson) {
  drillBits.push(JSON.parse(datajson));
};


// Define a modified populateDrillBitSelect function that accepts two or three parameters
function populateDrillBitSelect(drillBitData, methodStr) {
  // The drillBitData parameter represents your data source for the select options.
  // The methodStr parameter is used to identify the specific method (Hole, StraitCut, or Pocket).

  // Here, you can implement the logic to populate the select menu based on the provided parameters.
  // You can use methodStr to target the appropriate select menu.

  // Example logic (replace with your actual data and logic):
  const selectId = methodStr;
  const selectElement = document.getElementById(selectId);
//  if (selectElement) {
    // Clear existing options
    selectElement.innerHTML = "";

    // Populate the select menu based on drillBitData
    for (const drillBit of drillBitData) {
	  value = drillBit.Name
	  name = drillBit.Name.charAt(0).toUpperCase() + drillBit.Name.slice(1)
	  const option = document.createElement("option");
	  option.value = value;
  	  option.text = name + "  ("+drillBit.Cut_Diameter+drillBit.units+")";
	  selectElement.appendChild(option);
    }
//  }
}

