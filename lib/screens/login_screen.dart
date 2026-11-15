import 'package:flutter/material.dart';
import 'package:proyecto_final_moviles/config/email_auth.dart';


class LogginScreen extends StatefulWidget {
  const LogginScreen({super.key});

  @override
  State<LogginScreen> createState() => _LogginScreenState();
}

class _LogginScreenState extends State<LogginScreen> {
  EmailAuth? _emailAuth;
  final conUsaer = TextEditingController();
  final conPwd = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _emailAuth = EmailAuth();
  }

  @override
  Widget build(BuildContext context) {

    final txtUser = TextFormField(
      controller: conUsaer,
      decoration: InputDecoration(
        border: OutlineInputBorder()
      ),
    );
    final txtPwd = TextFormField(
      controller: conPwd,
      obscureText: true,
      decoration: InputDecoration(
        border: OutlineInputBorder()
      ),
    );

    final loading = Positioned(
      top: 150,
      child: CircularProgressIndicator()
    );

    final btnLogin = ElevatedButton(
      onPressed: (){
        isLoading = !isLoading;
        setState(() {});
        //Future.delayed(
        //  Duration(seconds: 4)
        //).then((value) {
        //  Navigator.pushNamed(context, "/dash");
        // isLoading = false;
        //  setState(() {});
        //});
        _emailAuth!.m_loginUser(user: conUsaer.text, password: conPwd.text).then((value) {
          if(value){
            Navigator.pushNamed(context, "/dash");
          }else{
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Usuario o contraseña incorrectos'),
                duration: Duration(seconds: 3)
              ),
            );
          }
          isLoading = false;
          setState(() {});
        },);
      },
      child: Row(
        children: [
          Icon(Icons.login),
          Text('Iniciar sesion')
        ],
      )
    );

    final space = Container(height: 5,);
    final space2 = SizedBox(height: 5,); 

    return Scaffold(
      body: Container(
        height: MediaQuery.of(context).size.height,
        width: MediaQuery.of(context).size.width,
        decoration: const BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.cover,
            image: AssetImage('assets/fondo.jpg')
          )
        ),
        child: Stack(
          alignment: AlignmentGeometry.center,
          children: [
            Image.asset('assets/logo.png', height: 200,),
            Positioned(
              bottom: 70,
              child: Container(
                padding: EdgeInsets.all(8),
                child: Column(
                  children: [
                    txtUser,
                    Divider(),
                    txtPwd,
                    space2,
                    btnLogin,
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: Text('Crear una cuenta'),
                    ),
                  ],
                ),
                height: 245,
                width: MediaQuery.of(context).size.width * .9,
                decoration: BoxDecoration(

                  borderRadius: BorderRadiusDirectional.circular(20),
                  color: Color(0x99FFFFFF)
                )
              ),
            ),
            isLoading ? loading : Container()
          ],
        ),
      )
    );
  }
}