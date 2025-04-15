const fs = require('fs');

fs.readFile('state.json', 'utf8', (err, data) => {
    if (err) {
        console.error('Error reading file:', err);
        return;
    }

    let state = JSON.parse(data);

    let numElements = state.all_uuids.length;
    console.log("Number of elements in all_uuids:", numElements);
});
