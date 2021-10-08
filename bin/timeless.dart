import 'dart:io';

import 'package:args/args.dart';
import 'package:common_utils/common_utils.dart';

void main(List<String> arguments) async {
  final argParser = ArgParser();
  argParser.addOption('path', abbr: 'p', help: '路径，默认为当前目录');
  argParser.addOption('author', abbr: 'a', help: '作者(必选项)');
  argParser.addOption('output', abbr: 'o', help: '导出文件');
  argParser.addFlag('month', abbr: 'm', help: '月历史', defaultsTo: false);
  argParser.addFlag('help', abbr: 'h', help: '帮助文档', defaultsTo: false);

  var results = argParser.parse(arguments);

  if (results.wasParsed('help')) {
    print('example:\n timeless -a laiiihz\n');
    print(argParser.usage);
    return;
  }

  var path = results['path'] as String?;
  var author = results['author'] as String?;
  if (author?.isEmpty ?? true) {
    print('AUTHOR CANT EMPTY');
    exit(0);
  }
  if (path?.isEmpty ?? true) {
    path = '.';
  }

  print(path);
  var date = DateTime.now();
  if (results['month']) {
    date = DateTime(date.year, date.month);
  }
  print((await Process.run('pwd', [])).stdout);
  var result = await Process.run(
    'git',
    [
      'log',
      '--author=$author',
      '--after=${DateUtil.formatDate(date, format: 'yyyy-M-d')} 0:00',
      '--date=format:%Y-%m-%d %H:%M:%S',
      '--shortstat',
      '--pretty=format:%cd@%s'
    ],
    workingDirectory: path,
    runInShell: true,
  );
  String rawResult = result.stdout;
  var _items = [];
  for (var i in rawResult.split('\n\n')) {
    var item = _Item.parse(i, full: results['month'] as bool?);
    _items.add(item);
    print(item);
  }

  var output = results['output'] as String?;
  if (output?.isNotEmpty ?? false) {
    var file = File(output!);
    if (!(await file.exists())) {
      await file.create();
    }
    await file.open();
    var temp = '';
    temp += '时间,备注,添加,删除\n';
    for (var i in _items) {
      temp += i.toString();
      temp += '\n';
    }
    await file.writeAsString(temp);
  }
}

class _Item {
  DateTime? date;
  String? commit = '';
  String? fileChange = '';
  String? add = '';
  String? delete = '';
  bool? fullPath = false;
  _Item({
    this.date,
    this.commit,
    this.fileChange,
    this.add,
    this.delete,
  });

  _Item.parse(String raw, {bool? full = false}) {
    fullPath = full;

    var midware = raw.replaceAll('\n', '@');
    if (midware.isNotEmpty && midware[0] == '@') {
      midware = midware.replaceFirst('@', '');
    }
    var lines = midware.split('@');
    if (lines.isNotEmpty && lines.length > 1) {
      date = DateUtil.getDateTime(lines.first);
      commit = lines[1];
      var changes = <String>[];
      if (lines.length >= 3) changes = lines[2].split(',');
      for (var item in changes) {
        if (item.contains('insertions(+)')) {
          add = item.replaceAll('insertions(+)', '');
          add = add!.replaceAll(' ', '');
        }
        if (item.contains('deletions(-)')) {
          delete = item.replaceAll('deletions(-)', '');
          delete = delete!.replaceAll(' ', '');
        }
      }
    }
  }

  @override
  String toString() {
    var dateTime = DateUtil.formatDate(
      date,
      format: fullPath! ? 'yyyy-MM-dd HH:mm' : 'HH:mm',
    );
    var displayCommit = commit!.replaceAll(',', ' ');
    return '$dateTime,$displayCommit,$add,$delete';
  }
}
