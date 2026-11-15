/*
  WSClient.js
  Cliente mínimo para consumir el servicio REST desde prueba.html.
  Todas las funciones son asíncronas y llaman a callback(codigoHTTP, resultado), donde
  resultado es el cuerpo de la respuesta ya convertido de JSON (o texto si no era JSON).

    var c = new WSClient("/Servicio/rest/ws");
    c.get("login", {email: .., password: ..}, function(code, result) { ... });
    c.post("alta_usuario", objeto, function(code, result) { ... });
    c.put("modifica_usuario", {id_usuario: .., token: ..}, objeto, function(code, result) { ... });
    c.delete("borra_usuario", {id_usuario: .., token: ..}, function(code, result) { ... });
*/

function WSClient(url)
{
	this.url = url;
}

WSClient.prototype.consulta = function(metodo, recurso, parametros, cuerpo, callback)
{
	var url = this.url + "/" + recurso;
	if (parametros)
	{
		var pares = [];
		for (var nombre in parametros)
			if (parametros[nombre] !== undefined && parametros[nombre] !== null)
				pares.push(encodeURIComponent(nombre) + "=" + encodeURIComponent(parametros[nombre]));
		if (pares.length > 0)
			url += "?" + pares.join("&");
	}

	var xhr = new XMLHttpRequest();
	xhr.open(metodo, url, true);
	if (cuerpo !== null)
		xhr.setRequestHeader("Content-Type", "application/json");
	xhr.onreadystatechange = function()
	{
		if (xhr.readyState != 4)
			return;
		var resultado = xhr.responseText;
		try
		{
			resultado = JSON.parse(xhr.responseText);
		}
		catch (e)
		{
			if (xhr.status == 0)
				resultado = {mensaje: "No se pudo conectar con el servidor"};
		}
		callback(xhr.status, resultado);
	};
	xhr.send(cuerpo !== null ? JSON.stringify(cuerpo) : null);
};

WSClient.prototype.get = function(recurso, parametros, callback)
{
	this.consulta("GET", recurso, parametros, null, callback);
};

WSClient.prototype.post = function(recurso, cuerpo, callback)
{
	this.consulta("POST", recurso, null, cuerpo, callback);
};

WSClient.prototype.put = function(recurso, parametros, cuerpo, callback)
{
	this.consulta("PUT", recurso, parametros, cuerpo, callback);
};

WSClient.prototype.delete = function(recurso, parametros, callback)
{
	this.consulta("DELETE", recurso, parametros, null, callback);
};
