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
  // Clase que representa una cuenta bancaria
  class Cuenta(Nombre : Text, ContrasenaHash : Text) {
    var hashContrasena = ContrasenaHash; // Almacena el hash de la contraseña
    public var nombre = Nombre; // Nombre del titular de la cuenta
    var Balance : Int = 0; // Saldo de la cuenta
    var tokens = Buffer.Buffer<Text>(10); // Buffer para almacenar tokens de sesión activos

    // Función privada para generar un token aleatorio
    private func generarTokenAleatorio() : async Text {
      let randomBytes = await Random.blob(); // Obtener una fuente de aleatoriedad
      var random = Random.Finite(randomBytes);
      var token = "";

      // Lista de caracteres permitidos en el token
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
            random := Random.Finite(await Random.blob()); // Generar más aleatoriedad si es necesario
            switch (random.byte()) {
              case (?b) {
                let indice = Nat8.toNat(b) % longitudCaracteres;
                token := token # Char.toText(caracteres[indice]);
              };
              case null {
                token := token # "A"; // Caso extremo, evitar errores
              };
            };
          };
        };
      };
      
      return token;
    };

    // Método para iniciar sesión con una contraseña válida
    public func iniciarSesion(Contrasena : Text) : async Text {
      if (Contrasena == hashContrasena) {
        let tokenNuevo = await generarTokenAleatorio(); // Generar un nuevo token de sesión
        tokens.add(tokenNuevo);
        return tokenNuevo;
      } else {
        return "Contraseña Incorrecta";
      }
    };

    // Verificar si un token es válido
    public func TokenValido(Token : Text) : async Bool {
      return Buffer.contains<Text>(tokens, Token, Text.equal);
    };
    
    // Método para depositar saldo en la cuenta
    public func Depositar(Token : Text, Valor : Int) : async Text {
       if (await TokenValido(Token)) {
          Balance := Balance + Valor; // Aumentar el saldo
          return "Deposito Exitoso"; 
       } else {
          return "Token Invalido";
       }
     };

    // Método para retirar saldo de la cuenta
    public func Cobrar(Token : Text, Valor : Int) : async Text {
       if (await TokenValido(Token) and Balance > Valor) {
          Balance := Balance - Valor; // Disminuir el saldo
          return "Cobro Exitoso"; 
       } else {
          return "Ocurrio un Error"; // Error si el saldo es insuficiente o el token no es válido
       }
     };

    // Consultar el saldo de la cuenta
    public func LeerBalance(Token : Text) : async Int { 
       if (await TokenValido(Token)) {
          return Balance; // Retorna el saldo actual
       } else {
          return -322293; // Código de error en caso de token inválido
       }
     };

    // Cerrar sesión eliminando el token de la lista
    public func cerrarSesion(Token : Text) : async Text {
        if (await TokenValido(Token)) {
            let nuevosTokens = Buffer.Buffer<Text>(tokens.size());
            for (t in tokens.vals()) {
                if (t != Token) {
                    nuevosTokens.add(t);
                }
            };
            tokens := nuevosTokens; // Actualiza la lista de tokens
            return "Sesión cerrada";
        } else {
            return "Token inválido";
        }
    };
  };

  var cuentas = Buffer.Buffer<Cuenta>(10); // Lista de cuentas almacenadas en el sistema

  // Método para encontrar una cuenta basada en un token
  public func EncontrarPorToken(Token : Text) : async Nat {
    let cuentasArray = Buffer.toArray(cuentas);
    for (i in Iter.range(0, Array.size(cuentasArray) - 1)) {
        if (await cuentasArray[i].TokenValido(Token)) {
            return i;
        };
    };
    return 0; // Si no se encuentra, retorna 0
  };

  // Función para transferir saldo entre cuentas
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
}
