
class NotFoundException implements Exception {
  String path;
  NotFoundException(this.path);

  @override
  String toString(){
    return 'NotFoundException: $path';
  }
}