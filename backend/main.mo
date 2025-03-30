import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Text "mo:base/Text";
import Random "mo:base/Random";
import Array "mo:base/Array";
import Char "mo:base/Char";
import Iter "mo:base/Iter";
import Buffer "mo:base/Buffer";
import Int "mo:base/Int";

actor {
  class Cuenta(Nombre : Text, ContrasenaHash : Text) {
    var hashContrasena = ContrasenaHash;
    public var nombre = Nombre;
    var Balance : Int = 0;
    var tokens = Buffer.Buffer<Text>(10);

      private func generarTokenAleatorio() : async Text {
      let randomBytes = await Random.blob();
      var random = Random.Finite(randomBytes);
      var token = "";

      // Convertir a un array para acceso por índice
      let caracteres = Text.toArray("0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ");
      let longitudCaracteres = caracteres.size();

      // Generar un token de 32 caracteres
      for (i in Iter.range(0, 31)) {
        switch (random.byte()) {
          case (?b) {
            let indice = Nat8.toNat(b) % longitudCaracteres;
            token := token # Char.toText(caracteres[indice]);
          };
          case null {
            // Si se agota la entropía, solicitar más
            random := Random.Finite(await Random.blob());
            
            // Intentar nuevamente con la nueva entropía
            switch (random.byte()) {
              case (?b) {
                let indice = Nat8.toNat(b) % longitudCaracteres;
                token := token # Char.toText(caracteres[indice]);
              };
              case null {
                token := token # "A"; // Caso extremo
              };
            };
          };
        };
      };
      
      return token;
    };

    // Método para iniciar sesión (Update porque modifica el estado)
    public func iniciarSesion(Contrasena : Text) : async Text {
      if (Contrasena == hashContrasena) {
        let tokenNuevo = await generarTokenAleatorio();  // Llamar a la función para generar el token
        tokens.add(tokenNuevo);  // Usamos Buffer.add en vez de Array.append
        return tokenNuevo;
      } else {
        return "Contraseña Incorrecta";
      }
    };

    public func TokenValido(Token : Text) : async Bool {
      return Buffer.contains<Text>(tokens, Token, Text.equal);
    };
    
    public func Depositar(Token : Text, Valor : Int) : async Text {
       if (await TokenValido(Token)) {
          Balance := Balance + Valor;
          return "Deposito Exitoso"; 
       } else {
          return "Token Invalido";
       }
     };

    public func Cobrar(Token : Text, Valor : Int) : async Text {
       let esValido = await TokenValido(Token);
       if (esValido and Balance > Valor) {
          Balance := Balance - Valor; 
          return "Cobro Exitoso"; 
       } else {
          return "Ocurrio un Error";
       }
     };

    public func LeerBalance(Token : Text) : async Int { 
       if (await TokenValido(Token)) {
          return Balance;
       } else {
          return -322293;
       }
     };

    public func cerrarSesion(Token : Text) : async Text {
        if (await TokenValido(Token)) {
            let nuevosTokens = Buffer.Buffer<Text>(tokens.size());
            for (t in tokens.vals()) {
                if (t != Token) {
                    nuevosTokens.add(t);
                }
            };
            tokens := nuevosTokens;
            return "Sesión cerrada";
        } else {
            return "Token inválido";
        }
    };
  };

  var cuentas = Buffer.Buffer<Cuenta>(10);

  public func EncontrarPorToken(Token : Text) : async Nat {
    let cuentasArray = Buffer.toArray(cuentas);
    for (i in Iter.range(0, Array.size(cuentasArray) - 1)) {
        if (await cuentasArray[i].TokenValido(Token)) {
            return i  // Convert Int to Nat
        };
    };
    return 0;  // Error value, ensure it returns a Nat
  };

  public func Deposita(Token : Text, Indice : Nat, Total : Int) : async Text {
    let cuentasArray = Buffer.toArray(cuentas);
    return await cuentasArray[Indice].Depositar(Token, Total);
  };

  public func Cobra(Token : Text, Indice : Nat, Total : Int) : async Text {
    let cuentasArray = Buffer.toArray(cuentas);
    return await cuentasArray[Indice].Cobrar(Token, Total);
  };

  public func ComprobarToken(Token : Text) : async Bool {
    let cuentasArray = Buffer.toArray(cuentas);
    for (i in Iter.range(0, Array.size(cuentasArray) - 1)) {
        if (await cuentasArray[i].TokenValido(Token)) {
            return true;
        };
    };
    return false;
  };

  public func Transferencia(TokenDestinatario : Text, TokenRemitente : Text, Monto : Int) : async Text {
    let destinatarioIndex = await EncontrarPorToken(TokenDestinatario);
    let remitenteIndex = await EncontrarPorToken(TokenRemitente);
    let DestinatarioValido = await ComprobarToken(TokenDestinatario);
    let RemitenteValido = await ComprobarToken(TokenRemitente);
    
    if (DestinatarioValido and RemitenteValido) {
        let resultadoCobro = await Cobra(TokenRemitente, remitenteIndex, Monto);
        if (resultadoCobro == "Ocurrio un Error") {
          return "Fondos insuficientes";
        };
        let _ = await Deposita(TokenDestinatario, destinatarioIndex, Monto);
        return "Transferencia Exitosa";
      } else {
        return "Uno o ambos tokens son Invalidos";
      };
  };

  public func ConseguirBalance(Token : Text, Indice : Nat) : async Int {
    let cuentasArray = Buffer.toArray(cuentas);
    return await cuentasArray[Indice].LeerBalance(Token);
  };

  public func CrearCuenta(Nombre : Text, Contrasena : Text) : async Text {
  let contrasenaHash = Contrasena;
  let nuevaCuenta = Cuenta(Nombre, contrasenaHash);
  cuentas.add(nuevaCuenta); // Añadir la nueva cuenta al Buffer de cuentas
  
  let tokenNuevo = await nuevaCuenta.iniciarSesion(Contrasena); // Generar el token de la nueva cuenta
  return tokenNuevo; // Devolver el token generado
};

  public func IniciarSesion(Nombre : Text, Contrasena : Text) : async Text {
  // Recorrer todas las cuentas en el Buffer
  for (cuenta in cuentas.vals()) {
    // Verificar si el nombre de la cuenta coincide
    if (cuenta.nombre == Nombre) {
      // Intentar iniciar sesión con la contraseña
      return await cuenta.iniciarSesion(Contrasena);
    };
  };

  // Si no se encuentra la cuenta
  return "Cuenta no encontrada";
};

 public func CerrarSesion(Token : Text) : async Text {
  let cuentaIndex = await EncontrarPorToken(Token);
  if (cuentaIndex == 0) {
    return "Token inválido"; // Si no se encuentra el token
  };
  let cuentasArray = Buffer.toArray(cuentas);
  let cuenta = cuentasArray[cuentaIndex];
  return await cuenta.cerrarSesion(Token); // Llamar al método
 };
}
