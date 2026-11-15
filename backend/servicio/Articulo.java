/*
  DTO de artículo: cuerpo de alta_articulo y elementos de los arreglos que regresan
  consulta_articulos y consulta_carrito_compra (en el carrito, "cantidad" es la
  cantidad comprada). Los campos nulos no se incluyen en el JSON.
*/

package servicio;

import java.math.BigDecimal;
import com.fasterxml.jackson.annotation.JsonInclude;

@JsonInclude(JsonInclude.Include.NON_NULL)
public class Articulo
{
  public Integer id_articulo;
  public String nombre;
  public String descripcion;
  public BigDecimal precio;
  public Integer cantidad;
  public byte[] fotografia;
}
