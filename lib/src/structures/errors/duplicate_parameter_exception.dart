/// Throws when a route contains duplicate parameters
///
class DuplicateParameterException implements Exception {
  final String name;
  DuplicateParameterException(this.name);

  @override
  String toString(){
    return 'DuplicateParameterException:   param name:$name';
  }
}