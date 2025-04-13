import 'dart:io';

import 'package:driver_cabbieo/pages/dashboard.dart';
import 'package:driver_cabbieo/screens/auth/login_screen.dart';
import 'package:driver_cabbieo/screens/costom%20widgets/costom_text_feild.dart';
import 'package:driver_cabbieo/screens/costom%20widgets/loading_screen.dart';
import 'package:driver_cabbieo/screens/costom%20widgets/terms_and_conditions.dart';
import 'package:driver_cabbieo/screens/methods/common_methods.dart';
import 'package:driver_cabbieo/screens/rider/home_rider_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';


class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  TextEditingController userNameTextEditingController=TextEditingController();
  TextEditingController emailTextEditingController = TextEditingController();
  TextEditingController passwordTextEditingController = TextEditingController();
  TextEditingController confirmPasswordTextEditingController =TextEditingController();
  TextEditingController phoneTextEditingController =TextEditingController();
  TextEditingController vehicleModelTextEditingController = TextEditingController();
  TextEditingController vehicleColorTextEditingController =TextEditingController();
  TextEditingController vehicleNumberTextEditingController =TextEditingController();
  CommonMethods cMethods=CommonMethods();
  final TermsAndConditionsController _controller = TermsAndConditionsController();
  XFile? imageFile;
  String urlOfUploadedImage="";

  
  
  

  checkInternetConnection(){
    
    if (imageFile!=null){
      signupFormValidation();
      
    }else{
      cMethods.displaySnackBar("Please select the profile image first.", context);
    }
    
  }

  

  void signupFormValidation() {
  // Validate all fields
  if (userNameTextEditingController.text.isEmpty) {
    cMethods.displaySnackBar("Please enter your username", context);
  } else if (emailTextEditingController.text.isEmpty) {
    cMethods.displaySnackBar("Please enter your email", context);
  } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
      .hasMatch(emailTextEditingController.text)) {
    cMethods.displaySnackBar("Please enter a valid email address", context);
  } else if (passwordTextEditingController.text.isEmpty) {
    cMethods.displaySnackBar("Please enter your password", context);
  } else if (passwordTextEditingController.text.length < 6) {
    cMethods.displaySnackBar("Password must be at least 6 characters", context);
  } else if (confirmPasswordTextEditingController.text.isEmpty) {
    cMethods.displaySnackBar("Please confirm your password", context);
  } else if (confirmPasswordTextEditingController.text != passwordTextEditingController.text) {
    cMethods.displaySnackBar("Passwords do not match", context);
  } else if (phoneTextEditingController.text.isEmpty) {
    cMethods.displaySnackBar("Please enter your phone number", context);
  } else if (phoneTextEditingController.text.length != 10) {
    cMethods.displaySnackBar("Phone number must be 10 digits", context);
  } else if (vehicleModelTextEditingController.text.isEmpty) {
    cMethods.displaySnackBar("Please provide your vehicle model details", context);
  }else if (vehicleColorTextEditingController.text.isEmpty) {
    cMethods.displaySnackBar("Please enter vehicle color", context);
  }else if (vehicleNumberTextEditingController.text.isEmpty) {
    cMethods.displaySnackBar("Please enter vehicle number ", context);
  }else {
    // If all fields are valid, proceed with the sign-up logic
    uploadImageToStorage();
    
    // Add your sign-up logic here
  }
}

uploadImageToStorage() async{
    String imageIdName = DateTime.now().millisecondsSinceEpoch.toString();
    Reference referenceImage = FirebaseStorage.instance.ref().child("images").child(imageIdName);

    UploadTask uploadTask= referenceImage.putFile(File(imageFile!.path));
    TaskSnapshot snapshot = await uploadTask;
    urlOfUploadedImage = await snapshot.ref.getDownloadURL();
    setState(() {
      urlOfUploadedImage;
    });
    if(_controller.onSignIn()){
      regesterNewDriver();
    }
    
    

    

  }

  regesterNewDriver() async {
    showDialog(context: context, 
    barrierDismissible: false,
    builder: (BuildContext context) => LoadingScreen(messangeText: "Registering your account...."));

    final User? userFirebase=(
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailTextEditingController.text.trim(), password: passwordTextEditingController.text.trim()
      ).catchError((errorMsg)
      {
        Navigator.pop(context);
        cMethods.displaySnackBar(errorMsg.toString(), context);
      })

    ).user;

    if(!context.mounted)return
    Navigator.pop(context);

    DatabaseReference userRef = FirebaseDatabase.instance.ref().child("drivers").child(userFirebase!.uid);


    Map driverCarInfo={
      "carColor":vehicleColorTextEditingController.text.trim(),
      "carModel":vehicleModelTextEditingController.text.trim(),
      "carNumber":vehicleNumberTextEditingController.text.trim()
    };

    Map driverDataMap = {
      "photo":urlOfUploadedImage,
      "name":userNameTextEditingController.text.trim(),
      "email":emailTextEditingController.text.trim(),
      "phone":phoneTextEditingController.text.trim(),
      "id":userFirebase.uid,
      "car_details":driverCarInfo,
      "blockStatus":"no"
    };
    userRef.set(driverDataMap);

    Navigator.push(context, MaterialPageRoute(builder: (builder)=>Dashboard()));

  }

  chooseImageFromGallery() async{
    final  pickedFile= await ImagePicker().pickImage(source: ImageSource.gallery);

    if (pickedFile!=null){
      setState(() {
        imageFile = pickedFile ;
      });
    }
  }


      

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        Image.asset(
          "assets/logo/welcome.png",
          fit: BoxFit.cover,
          height: double.infinity,
          width: double.infinity,
        ),
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                SizedBox(
                  height: 20,
                ),

                imageFile == null ?

                Center(
                    child: SizedBox(
                  child:CircleAvatar(
                    radius: 90,
                    backgroundImage: AssetImage("assets/logo/man.png"),
                  ),
                )) : Center(
                    child: SizedBox(
                  child:Container(
                    height: 180,
                    width: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:  Colors.grey.shade100,
                      image: DecorationImage(image: FileImage(File(
                        imageFile!.path
                      )),
                      fit: BoxFit.fitHeight)
                    ),
                  )
                )),



                SizedBox(
                  height: 5,
                ),
                
                GestureDetector(
                  onTap: (){
                    chooseImageFromGallery();
                  },

                  child: Text(
                    "Select image",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 10,),
                Padding(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      CustomTextField(controller: userNameTextEditingController, labelText: "Driver Name", icon: Icons.person),
                      SizedBox(height: 22,),
                      CustomTextField(
                          controller: emailTextEditingController,
                          labelText: "Email Address",
                          icon: Icons.mail),
                      SizedBox(
                        height: 22,
                      ),
                      CustomTextField(
                          controller: phoneTextEditingController,
                          labelText: "Phone Number",
                          icon: Icons.call),
                      SizedBox(
                        height: 22,
                      ),
                      CustomTextField(
                          controller: passwordTextEditingController,
                          labelText: "Create New Password",
                          icon: Icons.password),
                      SizedBox(
                        height: 22,
                      ),
                      CustomTextField(
                          controller: confirmPasswordTextEditingController,
                          labelText: "Confirm Password",
                          icon: Icons.password),
                      SizedBox(
                        height: 22,
                      ),
                      CustomTextField(
                          controller: vehicleModelTextEditingController,
                          labelText: "Vehicle Model",
                          icon: Icons.car_repair),
                      SizedBox(
                        height: 22,
                      ),
                      CustomTextField(
                          controller: vehicleColorTextEditingController,
                          labelText: "Vehicle Color",
                          icon: Icons.color_lens),
                      SizedBox(
                        height: 22,
                      ),
                      CustomTextField(
                          controller: vehicleNumberTextEditingController,
                          labelText: "Vehicle number",
                          icon: Icons.rectangle_rounded),
                      SizedBox(
                        height: 22,
                      ),
                      TermsAndConditionsCheckbox(controller: _controller,),
                      ElevatedButton(
          onPressed: (){
            
            checkInternetConnection();
            
          },
          child: Text('Signup'),
          style: ElevatedButton.styleFrom(
            backgroundColor:  Colors.blueGrey.shade800,
            textStyle: TextStyle(color: Colors.black,fontWeight: FontWeight.bold),
            elevation: 10,
            foregroundColor: Colors.white
            
          ),
        ),
                      SizedBox(
                        height: 22,
                      ),
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            GestureDetector(
                                onTap: () {
                                  Navigator.pushReplacement(context,MaterialPageRoute(builder: (context) => LoginScreen()));
                                },
                                child: Text(
                                  "Login here",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue.shade600),
                                ))
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}
