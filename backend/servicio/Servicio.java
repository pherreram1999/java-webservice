/*
  Servicio.java
  Servicio web REST
  Carlos Pineda Guerrero. 2025,2026
*/

package servicio;

import javax.ws.rs.GET;
import javax.ws.rs.POST;
import javax.ws.rs.PUT;
import javax.ws.rs.DELETE;
import javax.ws.rs.Path;
import javax.ws.rs.Consumes;
import javax.ws.rs.Produces;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.QueryParam;
import javax.ws.rs.core.Response;
import javax.ws.rs.core.Application;

import java.sql.*;
import javax.sql.DataSource;
import org.apache.tomcat.dbcp.dbcp2.BasicDataSource; // pool de conexiones incluido en Tomcat (lib/tomcat-dbcp.jar)

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.security.SecureRandom;

import com.fasterxml.jackson.databind.ObjectMapper;

/*
 La URL del servicio web es http://localhost:8080/servicio/rest/ws
 Donde:
 servicio: dominio del servicio web (es decir, el nombre de archivo servicio.war)
 rest: se define en la etiqueta <url-pattern> de <servlet-mapping> en el archivo WEB-INF\web.xml
 ws: se define en la siguiente anotación @Path de la clase Servicio
*/

@Path("ws")
public class Servicio extends Application
{
  /*
   La conexión a la base de datos se configura con variables de entorno (las define dev.sh
   a partir del archivo .env o del sistema operativo):
   DB_HOST (localhost), DB_PORT (3306), DB_NAME (servicio_web), DB_USER, DB_PASSWORD
  */
  static String env(String nombre,String valorDefault)
  {
    String valor = System.getenv(nombre);
    return (valor != null && !valor.isEmpty()) ? valor : valorDefault;
  }

  static DataSource pool = null;
  static
  {
    try
    {
      BasicDataSource ds = new BasicDataSource();
      // El pool lo carga el classloader de Tomcat, el driver está en WEB-INF/lib de esta aplicación
      ds.setDriverClassLoader(Servicio.class.getClassLoader());
      ds.setDriverClassName("com.mysql.cj.jdbc.Driver");
      ds.setUrl("jdbc:mysql://" + env("DB_HOST","localhost") + ":" + env("DB_PORT","3306") + "/" + env("DB_NAME","servicio_web") + "?serverTimezone=UTC");
      ds.setUsername(env("DB_USER",null));
      ds.setPassword(env("DB_PASSWORD",""));
      ds.setMaxTotal(100);
      ds.setMaxIdle(30);
      ds.setMaxWaitMillis(10000);
      pool = ds;
    }
    catch(Exception e)
    {
      e.printStackTrace();
    }
  }

  static ObjectMapper j = new ObjectMapper().setDateFormat(new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS"));

  static final String caracteres = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  static final SecureRandom random = new SecureRandom();

  static String generarToken(int longitud)
  {
    StringBuilder sb = new StringBuilder(longitud);
    for (int i = 0; i < longitud; i++)
    {
      int index = random.nextInt(caracteres.length());
      sb.append(caracteres.charAt(index));
    }
    return sb.toString();
  }

  boolean verifica_acceso(Connection conexion,int id_usuario,String token) throws Exception
  {
    PreparedStatement stmt_1 = conexion.prepareStatement("SELECT 1 FROM usuarios WHERE id_usuario=? and token=?");
    try
    {
      stmt_1.setInt(1,id_usuario);
      stmt_1.setString(2,token);

      ResultSet rs = stmt_1.executeQuery();
      try
      {
        return rs.next();
      }
      finally
      {
        rs.close();
      }
    }
    finally
    {
      stmt_1.close();
    }
  }

  /*
   Regresa al stock las existencias de todo el carrito del usuario (un UPDATE por artículo)
   y borra el carrito (un solo DELETE). No maneja la transacción: la debe abrir quien la llama.
  */
  void vacia_carrito(Connection conexion,int id_usuario) throws Exception
  {
    ArrayList<int[]> articulos = new ArrayList<int[]>();

    PreparedStatement stmt_1 = conexion.prepareStatement("SELECT id_articulo,cantidad FROM carrito_compra WHERE id_usuario=? ORDER BY id_articulo FOR UPDATE");
    try
    {
      stmt_1.setInt(1,id_usuario);

      ResultSet rs = stmt_1.executeQuery();
      try
      {
        while (rs.next())
          articulos.add(new int[] { rs.getInt(1),rs.getInt(2) });
      }
      finally
      {
        rs.close();
      }
    }
    finally
    {
      stmt_1.close();
    }

    PreparedStatement stmt_2 = conexion.prepareStatement("UPDATE stock SET cantidad=cantidad+? WHERE id_articulo=?");
    try
    {
      for (int[] a : articulos)
      {
        stmt_2.setInt(1,a[1]);
        stmt_2.setInt(2,a[0]);
        stmt_2.executeUpdate();
      }
    }
    finally
    {
      stmt_2.close();
    }

    PreparedStatement stmt_3 = conexion.prepareStatement("DELETE FROM carrito_compra WHERE id_usuario=?");
    try
    {
      stmt_3.setInt(1,id_usuario);
      stmt_3.executeUpdate();
    }
    finally
    {
      stmt_3.close();
    }
  }

  @GET
  @Path("login")
  @Produces(MediaType.APPLICATION_JSON)
  public Response login(@QueryParam("email") String email,@QueryParam("password") String password) throws Exception
  {
    try
    {
      Connection conexion= pool.getConnection();

      try
      {
        PreparedStatement stmt_1 = conexion.prepareStatement("SELECT id_usuario FROM usuarios WHERE email=? and password=?");
        try
        {
          stmt_1.setString(1,email);
          stmt_1.setString(2,password);

          ResultSet rs = stmt_1.executeQuery();
          try
          {
            if (rs.next())
            {
              int id_usuario = rs.getInt(1);
              String token = generarToken(20);

              PreparedStatement stmt_2 = conexion.prepareStatement("UPDATE usuarios SET token=? WHERE id_usuario=?");
              try
              {
                stmt_2.setString(1,token);
                stmt_2.setInt(2,id_usuario);
                stmt_2.executeUpdate();
              }
              finally
              {
                stmt_2.close();
              }

              return Response.ok("{\"id_usuario\":" + id_usuario + "," + "\"token\":\"" + token + "\"}").build();
            }
            return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();
          }
          finally
          {
            rs.close();
          }
        }
        finally
        {
          stmt_1.close();
        }
      }
      finally
      {
        conexion.close();
      }
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @POST
  @Path("alta_usuario")
  @Consumes(MediaType.APPLICATION_JSON)
  @Produces(MediaType.APPLICATION_JSON)
  public Response alta(Usuario usuario) throws Exception
  {
    try
    {
      int id_usuario = 0;

      if (usuario.email == null || usuario.email.equals(""))
        throw new Exception("Se debe ingresar el email");

      if (usuario.password == null || usuario.password.equals(""))
        throw new Exception("Se debe ingresar la contraseña");

      if (usuario.nombre == null || usuario.nombre.equals(""))
        throw new Exception("Se debe ingresar el nombre");

      if (usuario.apellido_paterno == null || usuario.apellido_paterno.equals(""))
        throw new Exception("Se debe ingresar el apellido paterno");

      if (usuario.fecha_nacimiento == null)
        throw new Exception("Se debe ingresar la fecha de nacimiento");

      Connection conexion = pool.getConnection();

      try
      {
        conexion.setAutoCommit(false);

        PreparedStatement stmt_1 = conexion.prepareStatement("INSERT INTO usuarios(id_usuario,email,password,nombre,apellido_paterno,apellido_materno,fecha_nacimiento,telefono,genero) VALUES (0,?,?,?,?,?,?,?,?)",Statement.RETURN_GENERATED_KEYS);

        try
        {
          stmt_1.setString(1,usuario.email);
          stmt_1.setString(2,usuario.password);
          stmt_1.setString(3,usuario.nombre);
          stmt_1.setString(4,usuario.apellido_paterno);

          if (usuario.apellido_materno != null)
            stmt_1.setString(5,usuario.apellido_materno);
          else
            stmt_1.setNull(5,Types.VARCHAR);

          stmt_1.setTimestamp(6,usuario.fecha_nacimiento);

          if (usuario.telefono != null)
            stmt_1.setLong(7,usuario.telefono);
          else
            stmt_1.setNull(7,Types.BIGINT);

          if (usuario.genero != null)
            stmt_1.setString(8,usuario.genero);
          else
            stmt_1.setNull(8,Types.CHAR);

          stmt_1.executeUpdate();
        
          ResultSet rs = stmt_1.getGeneratedKeys();

          try
          {
            if (rs.next())
              id_usuario = rs.getInt(1); // Obtiene el ID del usuario que se insertó previamente
          }
          finally
          {
            rs.close();
          }

          if (id_usuario == 0)
            return Response.status(400).entity(j.writeValueAsString(new Respuesta("No se pudo obtener el ID del usuario"))).build();
        }
        finally
        {
          stmt_1.close();
        }

        if (usuario.foto != null)
        {
          PreparedStatement stmt_2 = conexion.prepareStatement("INSERT INTO fotos_usuarios(id_foto,foto,id_usuario) VALUES (0,?,?)");

          try
          {
            stmt_2.setBytes(1,usuario.foto);
            stmt_2.setInt(2,id_usuario);
            stmt_2.executeUpdate();
          }
          finally
          {
            stmt_2.close();
          }
        }
        conexion.commit();
      }
      catch (Exception e)
      {
        conexion.rollback();
        throw new Exception(e.getMessage());
      }
      finally
      {
        conexion.setAutoCommit(true);
        conexion.close();
      }
      return Response.ok(j.writeValueAsString(new Respuesta("Se dio de alta el usuario"))).build();
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @GET
  @Path("consulta_usuario")
  @Produces(MediaType.APPLICATION_JSON)
  public Response consulta(@QueryParam("id_usuario") int id_usuario,@QueryParam("token") String token) throws Exception
  {
    try
    {
      Connection conexion= pool.getConnection();

      try
      {
        if (!verifica_acceso(conexion,id_usuario,token))
          return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();

        PreparedStatement stmt_1 = conexion.prepareStatement("SELECT a.email,a.nombre,a.apellido_paterno,a.apellido_materno,a.fecha_nacimiento,a.telefono,a.genero,b.foto FROM usuarios a LEFT OUTER JOIN fotos_usuarios b ON a.id_usuario=b.id_usuario WHERE a.id_usuario=?");
        try
        {
          stmt_1.setInt(1,id_usuario);

          ResultSet rs = stmt_1.executeQuery();

          try
          {
            if (rs.next())
            {
              Usuario r = new Usuario();
              r.email = rs.getString(1);
              r.nombre = rs.getString(2);
              r.apellido_paterno = rs.getString(3);
              r.apellido_materno = rs.getString(4);
              r.fecha_nacimiento = rs.getTimestamp(5);
              r.telefono = rs.getObject(6) != null ? rs.getLong(6) : null;
              r.genero = rs.getString(7);
	      r.foto = rs.getBytes(8);
              return Response.ok().entity(j.writeValueAsString(r)).build();
            }
            return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();
          }
          finally
          {
            rs.close();
          }
        }
        finally
        {
          stmt_1.close();
        }
      }
      finally
      {
        conexion.close();
      }
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @PUT
  @Path("modifica_usuario")
  @Consumes(MediaType.APPLICATION_JSON)
  @Produces(MediaType.APPLICATION_JSON)
  public Response modifica(@QueryParam("id_usuario") int id_usuario,@QueryParam("token") String token,Usuario usuario) throws Exception
  {
    try
    {
      Connection conexion= pool.getConnection();

      try
      {
        if (!verifica_acceso(conexion,id_usuario,token))
          return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();

        if (usuario.email == null || usuario.email.equals(""))
          throw new Exception("Se debe ingresar el email");

        if (usuario.nombre == null || usuario.nombre.equals(""))
          throw new Exception("Se debe ingresar el nombre");

        if (usuario.apellido_paterno == null || usuario.apellido_paterno.equals(""))
          throw new Exception("Se debe ingresar el apellido paterno");

        if (usuario.fecha_nacimiento == null)
          throw new Exception("Se debe ingresar la fecha de nacimiento");

        conexion.setAutoCommit(false);

        try
        {
          PreparedStatement stmt_1 = conexion.prepareStatement("UPDATE usuarios SET email=?,nombre=?,apellido_paterno=?,apellido_materno=?,fecha_nacimiento=?,telefono=?,genero=? WHERE id_usuario=?");

          try
          {
            stmt_1.setString(1,usuario.email);
            stmt_1.setString(2,usuario.nombre);
            stmt_1.setString(3,usuario.apellido_paterno);

            if (usuario.apellido_materno != null)
              stmt_1.setString(4,usuario.apellido_materno);
            else
              stmt_1.setNull(4,Types.VARCHAR);

            stmt_1.setTimestamp(5,usuario.fecha_nacimiento);

            if (usuario.telefono != null)
              stmt_1.setLong(6,usuario.telefono);
            else
              stmt_1.setNull(6,Types.BIGINT);

            if (usuario.genero != null)
              stmt_1.setString(7,usuario.genero);
            else
              stmt_1.setNull(7,Types.CHAR);

            stmt_1.setInt(8,id_usuario);

            stmt_1.executeUpdate();
          }
          finally
          {
            stmt_1.close();
          }

          if (!usuario.password.equals(""))
          {
            PreparedStatement stmt_2 = conexion.prepareStatement("UPDATE usuarios SET password=? WHERE id_usuario=?");

            try
            {
              stmt_2.setString(1,usuario.password);
              stmt_2.setInt(2,id_usuario);
              stmt_2.executeUpdate();
            }
            finally
            {
              stmt_2.close();
            }
          }

          PreparedStatement stmt_3 = conexion.prepareStatement("DELETE FROM fotos_usuarios WHERE id_usuario=?");

          try
          {
            stmt_3.setInt(1,id_usuario);
            stmt_3.executeUpdate();
          }
          finally
          {
            stmt_3.close();
          }

          if (usuario.foto != null)
          {
            PreparedStatement stmt_4 = conexion.prepareStatement("INSERT INTO fotos_usuarios(id_foto,foto,id_usuario) VALUES (0,?,?)");

            try
            {
              stmt_4.setBytes(1,usuario.foto);
              stmt_4.setInt(2,id_usuario);
              stmt_4.executeUpdate();
            }
            finally
            {
              stmt_4.close();
            }
          }

          conexion.commit();
        }
        catch (Exception e)
        {
          conexion.rollback();
          throw new Exception(e.getMessage());
        }
        finally
        {
          conexion.setAutoCommit(true);
        }
      }
      finally
      {
        conexion.close();
      }
      return Response.ok(j.writeValueAsString(new Respuesta("Se modificó el usuario"))).build();
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @DELETE
  @Path("borra_usuario")
  @Produces(MediaType.APPLICATION_JSON)
  public Response borra(@QueryParam("id_usuario") int id_usuario,@QueryParam("token") String token) throws Exception
  {
    try
    {
      Connection conexion= pool.getConnection();

      try
      {
        if (!verifica_acceso(conexion,id_usuario,token))
          return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();

        PreparedStatement stmt_1 = conexion.prepareStatement("SELECT 1 FROM usuarios WHERE id_usuario=?");

        try
        {
          stmt_1.setInt(1,id_usuario);

          ResultSet rs = stmt_1.executeQuery();

          try
          {
            if (!rs.next())
              return Response.status(400).entity(j.writeValueAsString(new Respuesta("El email no existe"))).build();
          }
          finally
          {
            rs.close();
          }
        }
        finally
        {
          stmt_1.close();
        }

        conexion.setAutoCommit(false);

        try
        {
          // Lo que el usuario tenga en su carrito regresa al stock (carrito_compra referencia a usuarios)
          vacia_carrito(conexion,id_usuario);

          PreparedStatement stmt_2 = conexion.prepareStatement("DELETE FROM fotos_usuarios WHERE id_usuario=?");

          try
          {
            stmt_2.setInt(1,id_usuario);
            stmt_2.executeUpdate();
          }
          finally
          {
            stmt_2.close();
          }

          PreparedStatement stmt_3 = conexion.prepareStatement("DELETE FROM usuarios WHERE id_usuario=?");

          try
          {
            stmt_3.setInt(1,id_usuario);
            stmt_3.executeUpdate();
          }
          finally
          {
            stmt_3.close();
          }
          conexion.commit();
        }
        catch (Exception e)
        {
          conexion.rollback();
          throw new Exception(e.getMessage());
        }
        finally
        {
          conexion.setAutoCommit(true);
        }
      }
      finally
      {
        conexion.close();
      }
      return Response.ok(j.writeValueAsString(new Respuesta("Se borró el usuario"))).build();
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @POST
  @Path("alta_articulo")
  @Consumes(MediaType.APPLICATION_JSON)
  @Produces(MediaType.APPLICATION_JSON)
  public Response alta_articulo(@QueryParam("id_usuario") int id_usuario,@QueryParam("token") String token,Articulo articulo) throws Exception
  {
    try
    {
      if (articulo == null)
        throw new Exception("Se deben ingresar los datos del artículo");

      if (articulo.nombre == null || articulo.nombre.trim().equals(""))
        throw new Exception("Se debe ingresar el nombre del artículo");

      if (articulo.precio == null || articulo.precio.signum() < 0)
        throw new Exception("Se debe ingresar un precio válido");

      if (articulo.cantidad == null || articulo.cantidad < 0)
        throw new Exception("Se debe ingresar una cantidad válida");

      if (articulo.fotografia == null || articulo.fotografia.length == 0)
        throw new Exception("Se debe ingresar la fotografía del artículo");

      Connection conexion = pool.getConnection();

      try
      {
        if (!verifica_acceso(conexion,id_usuario,token))
          return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();

        int id_articulo = 0;

        conexion.setAutoCommit(false);

        try
        {
          PreparedStatement stmt_1 = conexion.prepareStatement("INSERT INTO stock(id_articulo,nombre,descripcion,precio,cantidad) VALUES (0,?,?,?,?)",Statement.RETURN_GENERATED_KEYS);

          try
          {
            stmt_1.setString(1,articulo.nombre.trim());

            if (articulo.descripcion != null && !articulo.descripcion.trim().equals(""))
              stmt_1.setString(2,articulo.descripcion.trim());
            else
              stmt_1.setNull(2,Types.VARCHAR);

            stmt_1.setBigDecimal(3,articulo.precio);
            stmt_1.setInt(4,articulo.cantidad);
            stmt_1.executeUpdate();

            ResultSet rs = stmt_1.getGeneratedKeys();

            try
            {
              if (rs.next())
                id_articulo = rs.getInt(1);
            }
            finally
            {
              rs.close();
            }

            if (id_articulo == 0)
              throw new Exception("No se pudo obtener el ID del artículo");
          }
          finally
          {
            stmt_1.close();
          }

          PreparedStatement stmt_2 = conexion.prepareStatement("INSERT INTO fotos_articulos(id_foto,fotografia,id_articulo) VALUES (0,?,?)");

          try
          {
            stmt_2.setBytes(1,articulo.fotografia);
            stmt_2.setInt(2,id_articulo);
            stmt_2.executeUpdate();
          }
          finally
          {
            stmt_2.close();
          }

          conexion.commit();
        }
        catch (Exception e)
        {
          conexion.rollback();
          throw new Exception(e.getMessage());
        }
        finally
        {
          conexion.setAutoCommit(true);
        }
      }
      finally
      {
        conexion.close();
      }
      return Response.ok(j.writeValueAsString(new Respuesta("OK"))).build();
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @GET
  @Path("consulta_articulos")
  @Produces(MediaType.APPLICATION_JSON)
  public Response consulta_articulos(@QueryParam("palabra") String palabra,@QueryParam("id_usuario") int id_usuario,@QueryParam("token") String token) throws Exception
  {
    try
    {
      if (palabra == null)
        palabra = "";

      Connection conexion = pool.getConnection();

      try
      {
        if (!verifica_acceso(conexion,id_usuario,token))
          return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();

        PreparedStatement stmt_1 = conexion.prepareStatement("SELECT a.id_articulo,a.nombre,a.descripcion,a.precio,b.fotografia FROM stock a LEFT OUTER JOIN fotos_articulos b ON a.id_articulo=b.id_articulo WHERE a.nombre LIKE ? OR a.descripcion LIKE ? ORDER BY a.nombre");
        try
        {
          stmt_1.setString(1,"%" + palabra + "%");
          stmt_1.setString(2,"%" + palabra + "%");

          ResultSet rs = stmt_1.executeQuery();
          try
          {
            ArrayList<Articulo> articulos = new ArrayList<Articulo>();
            while (rs.next())
            {
              Articulo r = new Articulo();
              r.id_articulo = rs.getInt(1);
              r.nombre = rs.getString(2);
              r.descripcion = rs.getString(3);
              r.precio = rs.getBigDecimal(4);
              r.fotografia = rs.getBytes(5);
              articulos.add(r);
            }
            return Response.ok(j.writeValueAsString(articulos)).build();
          }
          finally
          {
            rs.close();
          }
        }
        finally
        {
          stmt_1.close();
        }
      }
      finally
      {
        conexion.close();
      }
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @PUT
  @Path("compra_articulo")
  @Produces(MediaType.APPLICATION_JSON)
  public Response compra_articulo(@QueryParam("id_articulo") int id_articulo,@QueryParam("cantidad") int cantidad,@QueryParam("id_usuario") int id_usuario,@QueryParam("token") String token) throws Exception
  {
    try
    {
      if (cantidad <= 0)
        throw new Exception("La cantidad a comprar debe ser mayor que cero");

      Connection conexion = pool.getConnection();

      try
      {
        if (!verifica_acceso(conexion,id_usuario,token))
          return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();

        conexion.setAutoCommit(false);

        try
        {
          int existencia;

          // FOR UPDATE bloquea el artículo para que dos compras simultáneas no vendan más de lo que hay
          PreparedStatement stmt_1 = conexion.prepareStatement("SELECT cantidad FROM stock WHERE id_articulo=? FOR UPDATE");
          try
          {
            stmt_1.setInt(1,id_articulo);

            ResultSet rs = stmt_1.executeQuery();
            try
            {
              if (!rs.next())
                throw new Exception("El artículo no existe");
              existencia = rs.getInt(1);
            }
            finally
            {
              rs.close();
            }
          }
          finally
          {
            stmt_1.close();
          }

          if (cantidad > existencia)
            throw new Exception("No hay suficientes artículos en el stock");

          boolean en_carrito;

          PreparedStatement stmt_2 = conexion.prepareStatement("SELECT 1 FROM carrito_compra WHERE id_usuario=? AND id_articulo=?");
          try
          {
            stmt_2.setInt(1,id_usuario);
            stmt_2.setInt(2,id_articulo);

            ResultSet rs = stmt_2.executeQuery();
            try
            {
              en_carrito = rs.next();
            }
            finally
            {
              rs.close();
            }
          }
          finally
          {
            stmt_2.close();
          }

          if (en_carrito)
          {
            PreparedStatement stmt_3 = conexion.prepareStatement("UPDATE carrito_compra SET cantidad=cantidad+? WHERE id_usuario=? AND id_articulo=?");
            try
            {
              stmt_3.setInt(1,cantidad);
              stmt_3.setInt(2,id_usuario);
              stmt_3.setInt(3,id_articulo);
              stmt_3.executeUpdate();
            }
            finally
            {
              stmt_3.close();
            }
          }
          else
          {
            PreparedStatement stmt_3 = conexion.prepareStatement("INSERT INTO carrito_compra(id_usuario,id_articulo,cantidad) VALUES (?,?,?)");
            try
            {
              stmt_3.setInt(1,id_usuario);
              stmt_3.setInt(2,id_articulo);
              stmt_3.setInt(3,cantidad);
              stmt_3.executeUpdate();
            }
            finally
            {
              stmt_3.close();
            }
          }

          PreparedStatement stmt_4 = conexion.prepareStatement("UPDATE stock SET cantidad=cantidad-? WHERE id_articulo=?");
          try
          {
            stmt_4.setInt(1,cantidad);
            stmt_4.setInt(2,id_articulo);
            stmt_4.executeUpdate();
          }
          finally
          {
            stmt_4.close();
          }

          conexion.commit();
        }
        catch (Exception e)
        {
          conexion.rollback();
          throw new Exception(e.getMessage());
        }
        finally
        {
          conexion.setAutoCommit(true);
        }
      }
      finally
      {
        conexion.close();
      }
      return Response.ok(j.writeValueAsString(new Respuesta("OK"))).build();
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @GET
  @Path("consulta_carrito_compra")
  @Produces(MediaType.APPLICATION_JSON)
  public Response consulta_carrito_compra(@QueryParam("id_usuario") int id_usuario,@QueryParam("token") String token) throws Exception
  {
    try
    {
      Connection conexion = pool.getConnection();

      try
      {
        if (!verifica_acceso(conexion,id_usuario,token))
          return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();

        PreparedStatement stmt_1 = conexion.prepareStatement("SELECT a.id_articulo,b.nombre,b.precio,a.cantidad,c.fotografia FROM carrito_compra a INNER JOIN stock b ON a.id_articulo=b.id_articulo LEFT OUTER JOIN fotos_articulos c ON b.id_articulo=c.id_articulo WHERE a.id_usuario=? ORDER BY b.nombre");
        try
        {
          stmt_1.setInt(1,id_usuario);

          ResultSet rs = stmt_1.executeQuery();
          try
          {
            ArrayList<Articulo> articulos = new ArrayList<Articulo>();
            while (rs.next())
            {
              Articulo r = new Articulo();
              r.id_articulo = rs.getInt(1);
              r.nombre = rs.getString(2);
              r.precio = rs.getBigDecimal(3);
              r.cantidad = rs.getInt(4);
              r.fotografia = rs.getBytes(5);
              articulos.add(r);
            }
            return Response.ok(j.writeValueAsString(articulos)).build();
          }
          finally
          {
            rs.close();
          }
        }
        finally
        {
          stmt_1.close();
        }
      }
      finally
      {
        conexion.close();
      }
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @DELETE
  @Path("elimina_articulo_carrito_compra")
  @Produces(MediaType.APPLICATION_JSON)
  public Response elimina_articulo_carrito_compra(@QueryParam("id_usuario") int id_usuario,@QueryParam("id_articulo") int id_articulo,@QueryParam("token") String token) throws Exception
  {
    try
    {
      Connection conexion = pool.getConnection();

      try
      {
        if (!verifica_acceso(conexion,id_usuario,token))
          return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();

        conexion.setAutoCommit(false);

        try
        {
          int cantidad;

          PreparedStatement stmt_1 = conexion.prepareStatement("SELECT cantidad FROM carrito_compra WHERE id_usuario=? AND id_articulo=? FOR UPDATE");
          try
          {
            stmt_1.setInt(1,id_usuario);
            stmt_1.setInt(2,id_articulo);

            ResultSet rs = stmt_1.executeQuery();
            try
            {
              if (!rs.next())
                throw new Exception("El artículo no está en el carrito de compra");
              cantidad = rs.getInt(1);
            }
            finally
            {
              rs.close();
            }
          }
          finally
          {
            stmt_1.close();
          }

          PreparedStatement stmt_2 = conexion.prepareStatement("UPDATE stock SET cantidad=cantidad+? WHERE id_articulo=?");
          try
          {
            stmt_2.setInt(1,cantidad);
            stmt_2.setInt(2,id_articulo);
            stmt_2.executeUpdate();
          }
          finally
          {
            stmt_2.close();
          }

          PreparedStatement stmt_3 = conexion.prepareStatement("DELETE FROM carrito_compra WHERE id_usuario=? AND id_articulo=?");
          try
          {
            stmt_3.setInt(1,id_usuario);
            stmt_3.setInt(2,id_articulo);
            stmt_3.executeUpdate();
          }
          finally
          {
            stmt_3.close();
          }

          conexion.commit();
        }
        catch (Exception e)
        {
          conexion.rollback();
          throw new Exception(e.getMessage());
        }
        finally
        {
          conexion.setAutoCommit(true);
        }
      }
      finally
      {
        conexion.close();
      }
      return Response.ok(j.writeValueAsString(new Respuesta("OK"))).build();
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }

  @DELETE
  @Path("elimina_carrito_compra")
  @Produces(MediaType.APPLICATION_JSON)
  public Response elimina_carrito_compra(@QueryParam("id_usuario") int id_usuario,@QueryParam("token") String token) throws Exception
  {
    try
    {
      Connection conexion = pool.getConnection();

      try
      {
        if (!verifica_acceso(conexion,id_usuario,token))
          return Response.status(400).entity(j.writeValueAsString(new Respuesta("Acceso denegado"))).build();

        conexion.setAutoCommit(false);

        try
        {
          vacia_carrito(conexion,id_usuario);
          conexion.commit();
        }
        catch (Exception e)
        {
          conexion.rollback();
          throw new Exception(e.getMessage());
        }
        finally
        {
          conexion.setAutoCommit(true);
        }
      }
      finally
      {
        conexion.close();
      }
      return Response.ok(j.writeValueAsString(new Respuesta("OK"))).build();
    }
    catch (Exception e)
    {
      return Response.status(400).entity(j.writeValueAsString(new Respuesta(e.getMessage()))).build();
    }
  }
}
