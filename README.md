# Control Aires ITC

Aplicación Flutter con inicio de sesión Firebase, cuentas de usuario y un panel
de administración. Las altas, modificaciones y eliminaciones administrativas
se ejecutan en Firebase Cloud Functions; los perfiles se guardan en Realtime
Database.

## Preparar Firebase

1. En Firebase Authentication habilita correo/contraseña y los proveedores
   OAuth que vayas a utilizar.
2. Crea la primera cuenta administradora en Authentication.
3. En Realtime Database, crea `users/{UID_ADMIN}` con estos campos:

   ```json
   {
     "nombre": "Administrador",
     "email": "admin@ejemplo.com",
     "foto_url": "",
     "provider": "password",
     "role": "admin",
     "autorizado": true,
     "plan_suscripcion": "ninguno",
     "dispositivos_vinculados": {}
   }
   ```

   Reemplaza el UID y el correo con los de la cuenta creada. La aplicación no
   permite que un usuario se asigne el rol de administrador.
4. Instala las dependencias de Flutter y Functions:

   ```powershell
   flutter pub get
   cd functions
   npm install
   npm test
   cd ..
   ```

5. Despliega las reglas y las funciones al proyecto configurado en `.firebaserc`:

   ```powershell
   firebase deploy --only database,functions
   ```

   Cloud Functions requiere que el proyecto de Firebase tenga habilitada la
   facturación. No despliegues estas reglas antes de crear el perfil inicial
   de administrador o las operaciones de administración quedarán bloqueadas.

## Ejecutar y validar

```powershell
flutter run
flutter analyze
flutter test
```

El número asignado es un identificador ficticio de demostración, no es una
tarjeta de pago ni debe utilizarse para transacciones.
