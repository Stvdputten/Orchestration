// Define the column index you want to extract (0-based index)
const columnIndex = 7;

// Initialize an array to hold the modified strings
const modifiedStrings = [];

// Use a loop to select rows with specific IDs
for (let i = 0; i <= 8; i++) {
  // Construct the ID for each row
  const rowId = `listview-row-node${i}`;
  
  // Select the row using the ID
  const row = document.getElementById(rowId);
  
  // Check if the row exists
  if (row) {
    // Select the cell in the specified column
    const cell = row.children[columnIndex];
    
    // Check if the cell exists
    if (cell) {
      // Extract the text content from the cell
      let cellText = cell.innerText.trim();
      
      // Remove occurrences of "ssh" and remove whitespace
      cellText = cellText.replace(/ssh/g, '').replace(/\s+/g, '');

      // Add the modified text to the array
      modifiedStrings.push(cellText);
    }
  } else {
    console.warn(`Row with ID ${rowId} not found`);
  }
}

// Output the array of modified strings
console.log(modifiedStrings);


