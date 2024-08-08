import 'entity.dart';

class Module1 {
  // ignore: unnecessary_lambdas
  Object get class1 => () => Class1();

  Class2 get class2 => Class2();

  // ignore: unused_element
  Class3 _getClass3() => Class3();
}
