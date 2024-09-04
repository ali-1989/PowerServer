enum HttpMethod {
  get,
  post,
  put,
  delete,
  patch,
  options,
  head,
  copy,
  link,
  unlink,
  purge,
  lock,
  unlock,
  propfind,
  view,
  all;

  static HttpMethod from(String str) => HttpMethod.values.firstWhere(
        (method) => method.name == str,
    orElse: () => HttpMethod.get,
  );
}