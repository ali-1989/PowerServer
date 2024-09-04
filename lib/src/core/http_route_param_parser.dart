class RouteSegmentParamParser {
  static final List<SegmentParamParser> _parserList = [];

  static RouteSegmentParamParser? _instance;

  factory RouteSegmentParamParser(){
    if(_instance == null){
      _instance = RouteSegmentParamParser._init();
    }

    return _instance!;
  }

  RouteSegmentParamParser._init(){
    final alphabetParser = SegmentParamParser('alpha');
    alphabetParser.pattern = r'[0-9a-z_]+';
    alphabetParser.parser = (value) => value;
    //----------------------------------------
    final initParser = SegmentParamParser('int');
    initParser.pattern = r'-?\d+';
    initParser.parser = (value) => int.parse(value);
    //----------------------------------------
    final uintParser = SegmentParamParser('uint');
    uintParser.pattern = r'\d+';
    uintParser.parser = (value) => int.parse(value);
    //----------------------------------------
    final hexParser = SegmentParamParser('hex');
    hexParser.pattern = r'[0-9a-f]+';
    hexParser.parser = (value) => value;
    //----------------------------------------
    final doubleParser = SegmentParamParser('double');
    doubleParser.pattern = r'-?\d+(?:\.\d+)?';
    doubleParser.parser = (value) => double.parse(value);
    //----------------------------------------
    final uuidParser = SegmentParamParser('uuid');
    uuidParser.pattern = r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}';
    uuidParser.parser = (value) => value;
    //----------------------------------------
    final timestampParser = SegmentParamParser('timestamp');
    timestampParser.pattern = r'-?\d+';
    timestampParser.parser = (value) => DateTime.fromMillisecondsSinceEpoch(int.parse(value));
    //----------------------------------------
    final dateParser = SegmentParamParser('date');
    dateParser.pattern = r'-?\d{1,6}/(?:0[1-9]|1[012])/(?:0[1-9]|[12][0-9]|3[01])';
    dateParser.parser = (value) {
      final components = value.split('/').map(int.parse).toList();
      return DateTime.utc(components[0], components[1], components[2]);
    };
    //----------------------------------------
    _parserList.add(initParser);
    _parserList.add(uintParser);
    _parserList.add(doubleParser);
    _parserList.add(dateParser);
    _parserList.add(timestampParser);
    _parserList.add(hexParser);
    _parserList.add(alphabetParser);
    _parserList.add(uuidParser);
  }

  SegmentParamParser? getType(String typeName){
    return _parserList.cast<SegmentParamParser?>().firstWhere((t) => t!.name == typeName, orElse: () => null);
  }
}
///=============================================================================
class SegmentParamParser {
  String name;
  late String pattern;
  late dynamic Function(dynamic value) parser;

  SegmentParamParser(this.name);
}
