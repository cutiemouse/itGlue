function generateTableRow() {
	var emptyColumn = document.createElement('tr');
	emptyColumn.innerHTML = 
		'<td><label for="name">who</label><div><input type="text" name="company" placeholder="Who is this invoice to"></div></td>' +
		'<td><label for="quantity">quantity</label><div><input type="number" name="quantity" class="quantity"></div></td>' +
		'<td><label for="price">price</label><div class="priceRow"><input type="number" name="price" class="price"></div></td>' +
		'<td><span data-prefix>$</span><span>0</span></td>';
	return emptyColumn;
}

function addLine () {
	document.querySelector('#inventory tbody').appendChild(generateTableRow());		
}
	
	
