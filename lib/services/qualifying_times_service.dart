import '../database_helper.dart';
import '../models/qualifying_time.dart';

class QualifyingTimesService {
  final DatabaseHelper _dbHelper;

  QualifyingTimesService({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<void> seedAllStandards() async {
    final count = await _dbHelper.getQualifyingTimesCount();
    if (count > 0) return;

    await seedSnag2026Female();
    await seedSnag2026Male();
  }

  Future<void> seedSnag2026Female() async {
    final List<QualifyingTime> times = [
      // 50 Freestyle
      _qt("50 Freestyle", 7, 8, 50000, "Female"),
      _qt("50 Freestyle", 9, 9, 45370, "Female"),
      _qt("50 Freestyle", 10, 10, 41530, "Female"),
      _qt("50 Freestyle", 11, 11, 38930, "Female"),
      _qt("50 Freestyle", 12, 12, 35210, "Female"),
      _qt("50 Freestyle", 13, 14, 33250, "Female"),
      _qt("50 Freestyle", 15, 17, 32330, "Female"),
      _qt("50 Freestyle", 18, 99, 31580, "Female"),

      // 100 Freestyle
      _qt("100 Freestyle", 7, 8, 114950, "Female"),
      _qt("100 Freestyle", 9, 9, 100380, "Female"),
      _qt("100 Freestyle", 10, 10, 91790, "Female"),
      _qt("100 Freestyle", 11, 11, 85780, "Female"),
      _qt("100 Freestyle", 12, 12, 80590, "Female"),
      _qt("100 Freestyle", 13, 14, 71860, "Female"),
      _qt("100 Freestyle", 15, 17, 69630, "Female"),
      _qt("100 Freestyle", 18, 99, 67910, "Female"),

      // 200 Freestyle
      _qt("200 Freestyle", 9, 9, 223090, "Female"),
      _qt("200 Freestyle", 10, 10, 201320, "Female"),
      _qt("200 Freestyle", 11, 11, 189550, "Female"),
      _qt("200 Freestyle", 12, 12, 176750, "Female"),
      _qt("200 Freestyle", 13, 14, 157770, "Female"),
      _qt("200 Freestyle", 15, 17, 152750, "Female"),
      _qt("200 Freestyle", 18, 99, 150650, "Female"),

      // 400 Freestyle
      _qt("400 Freestyle", 11, 11, 404860, "Female"),
      _qt("400 Freestyle", 12, 12, 375530, "Female"),
      _qt("400 Freestyle", 13, 14, 333120, "Female"),
      _qt("400 Freestyle", 15, 17, 326510, "Female"),
      _qt("400 Freestyle", 18, 99, 323840, "Female"),

      // 800 Freestyle
      _qt("800 Freestyle", 11, 11, 773830, "Female"),
      _qt("800 Freestyle", 12, 12, 773830, "Female"),
      _qt("800 Freestyle", 13, 14, 693160, "Female"),
      _qt("800 Freestyle", 15, 17, 682220, "Female"),
      _qt("800 Freestyle", 18, 99, 674510, "Female"),

      // 1500 Freestyle
      _qt("1500 Freestyle", 11, 11, 1439740, "Female"),
      _qt("1500 Freestyle", 12, 12, 1439740, "Female"),
      _qt("1500 Freestyle", 13, 14, 1378940, "Female"),
      _qt("1500 Freestyle", 15, 17, 1314690, "Female"),
      _qt("1500 Freestyle", 18, 99, 1274260, "Female"),

      // 50 Backstroke
      _qt("50 Backstroke", 7, 8, 59180, "Female"),
      _qt("50 Backstroke", 9, 9, 53940, "Female"),
      _qt("50 Backstroke", 10, 10, 48480, "Female"),
      _qt("50 Backstroke", 11, 11, 45290, "Female"),
      _qt("50 Backstroke", 12, 12, 42980, "Female"),
      _qt("50 Backstroke", 13, 14, 38210, "Female"),
      _qt("50 Backstroke", 15, 17, 37580, "Female"),
      _qt("50 Backstroke", 18, 99, 36700, "Female"),

      // 100 Backstroke
      _qt("100 Backstroke", 7, 8, 129800, "Female"),
      _qt("100 Backstroke", 9, 9, 117930, "Female"),
      _qt("100 Backstroke", 10, 10, 105070, "Female"),
      _qt("100 Backstroke", 11, 11, 99320, "Female"),
      _qt("100 Backstroke", 12, 12, 93280, "Female"),
      _qt("100 Backstroke", 13, 14, 82640, "Female"),
      _qt("100 Backstroke", 15, 17, 79990, "Female"),
      _qt("100 Backstroke", 18, 99, 79480, "Female"),

      // 200 Backstroke
      _qt("200 Backstroke", 11, 11, 215370, "Female"),
      _qt("200 Backstroke", 12, 12, 202170, "Female"),
      _qt("200 Backstroke", 13, 14, 178810, "Female"),
      _qt("200 Backstroke", 15, 17, 178530, "Female"),
      _qt("200 Backstroke", 18, 99, 175580, "Female"),

      // 50 Breaststroke
      _qt("50 Breaststroke", 7, 8, 65590, "Female"),
      _qt("50 Breaststroke", 9, 9, 59170, "Female"),
      _qt("50 Breaststroke", 10, 10, 54170, "Female"),
      _qt("50 Breaststroke", 11, 11, 50290, "Female"),
      _qt("50 Breaststroke", 12, 12, 47750, "Female"),
      _qt("50 Breaststroke", 13, 14, 42500, "Female"),
      _qt("50 Breaststroke", 15, 17, 41620, "Female"),
      _qt("50 Breaststroke", 18, 99, 40100, "Female"),

      // 100 Breaststroke
      _qt("100 Breaststroke", 7, 8, 143690, "Female"),
      _qt("100 Breaststroke", 9, 9, 129080, "Female"),
      _qt("100 Breaststroke", 10, 10, 116300, "Female"),
      _qt("100 Breaststroke", 11, 11, 110860, "Female"),
      _qt("100 Breaststroke", 12, 12, 103810, "Female"),
      _qt("100 Breaststroke", 13, 14, 92630, "Female"),
      _qt("100 Breaststroke", 15, 17, 89850, "Female"),
      _qt("100 Breaststroke", 18, 99, 88910, "Female"),

      // 200 Breaststroke
      _qt("200 Breaststroke", 11, 11, 238540, "Female"),
      _qt("200 Breaststroke", 12, 12, 224860, "Female"),
      _qt("200 Breaststroke", 13, 14, 200890, "Female"),
      _qt("200 Breaststroke", 15, 17, 194640, "Female"),
      _qt("200 Breaststroke", 18, 99, 193950, "Female"),

      // 50 Butterfly
      _qt("50 Butterfly", 7, 8, 56780, "Female"),
      _qt("50 Butterfly", 9, 9, 49670, "Female"),
      _qt("50 Butterfly", 10, 10, 44740, "Female"),
      _qt("50 Butterfly", 11, 11, 41760, "Female"),
      _qt("50 Butterfly", 12, 12, 39970, "Female"),
      _qt("50 Butterfly", 13, 14, 35450, "Female"),
      _qt("50 Butterfly", 15, 17, 34450, "Female"),
      _qt("50 Butterfly", 18, 99, 33860, "Female"),

      // 100 Butterfly
      _qt("100 Butterfly", 7, 8, 133780, "Female"),
      _qt("100 Butterfly", 9, 9, 117980, "Female"),
      _qt("100 Butterfly", 10, 10, 106220, "Female"),
      _qt("100 Butterfly", 11, 11, 96550, "Female"),
      _qt("100 Butterfly", 12, 12, 90570, "Female"),
      _qt("100 Butterfly", 13, 14, 78820, "Female"),
      _qt("100 Butterfly", 15, 17, 76790, "Female"),
      _qt("100 Butterfly", 18, 99, 74870, "Female"),

      // 200 Butterfly
      _qt("200 Butterfly", 11, 11, 227740, "Female"),
      _qt("200 Butterfly", 12, 12, 210890, "Female"),
      _qt("200 Butterfly", 13, 14, 180470, "Female"),
      _qt("200 Butterfly", 15, 17, 175060, "Female"),
      _qt("200 Butterfly", 18, 99, 173980, "Female"),

      // 200 IM
      _qt("200 IM", 9, 9, 247210, "Female"),
      _qt("200 IM", 10, 10, 224710, "Female"),
      _qt("200 IM", 11, 11, 212240, "Female"),
      _qt("200 IM", 12, 12, 199330, "Female"),
      _qt("200 IM", 13, 14, 176560, "Female"),
      _qt("200 IM", 15, 17, 174880, "Female"),
      _qt("200 IM", 18, 99, 175010, "Female"),

      // 400 IM
      _qt("400 IM", 11, 11, 446440, "Female"),
      _qt("400 IM", 12, 12, 430740, "Female"),
      _qt("400 IM", 13, 14, 384210, "Female"),
      _qt("400 IM", 15, 17, 376920, "Female"),
      _qt("400 IM", 18, 99, 369080, "Female"),
    ];

    for (var qt in times) {
      await _dbHelper.insertQualifyingTime(qt);
    }
  }

  Future<void> seedSnag2026Male() async {
    final List<QualifyingTime> times = [
      // 50 Freestyle
      _qt("50 Freestyle", 7, 8, 46680, "Male"),
      _qt("50 Freestyle", 9, 9, 42270, "Male"),
      _qt("50 Freestyle", 10, 10, 39250, "Male"),
      _qt("50 Freestyle", 11, 11, 38470, "Male"),
      _qt("50 Freestyle", 12, 12, 36370, "Male"),
      _qt("50 Freestyle", 13, 14, 30640, "Male"),
      _qt("50 Freestyle", 15, 17, 29000, "Male"),
      _qt("50 Freestyle", 18, 99, 27990, "Male"),

      // 100 Freestyle
      _qt("100 Freestyle", 7, 8, 105380, "Male"),
      _qt("100 Freestyle", 9, 9, 94140, "Male"),
      _qt("100 Freestyle", 10, 10, 88760, "Male"),
      _qt("100 Freestyle", 11, 11, 84320, "Male"),
      _qt("100 Freestyle", 12, 12, 79590, "Male"),
      _qt("100 Freestyle", 13, 14, 67070, "Male"),
      _qt("100 Freestyle", 15, 17, 63240, "Male"),
      _qt("100 Freestyle", 18, 99, 60920, "Male"),

      // 200 Freestyle
      _qt("200 Freestyle", 9, 9, 204500, "Male"),
      _qt("200 Freestyle", 10, 10, 192880, "Male"),
      _qt("200 Freestyle", 11, 11, 183450, "Male"),
      _qt("200 Freestyle", 12, 12, 173280, "Male"),
      _qt("200 Freestyle", 13, 14, 147030, "Male"),
      _qt("200 Freestyle", 15, 17, 138840, "Male"),
      _qt("200 Freestyle", 18, 99, 134790, "Male"),

      // 400 Freestyle
      _qt("400 Freestyle", 11, 11, 386400, "Male"),
      _qt("400 Freestyle", 12, 12, 363770, "Male"),
      _qt("400 Freestyle", 13, 14, 312420, "Male"),
      _qt("400 Freestyle", 15, 17, 296610, "Male"),
      _qt("400 Freestyle", 18, 99, 292730, "Male"),

      // 800 Freestyle
      _qt("800 Freestyle", 11, 11, 768360, "Male"),
      _qt("800 Freestyle", 12, 12, 768360, "Male"),
      _qt("800 Freestyle", 13, 14, 684670, "Male"),
      _qt("800 Freestyle", 15, 17, 626950, "Male"),
      _qt("800 Freestyle", 18, 99, 620440, "Male"),

      // 1500 Freestyle
      _qt("1500 Freestyle", 11, 11, 1429740, "Male"),
      _qt("1500 Freestyle", 12, 12, 1429740, "Male"),
      _qt("1500 Freestyle", 13, 14, 1283880, "Male"),
      _qt("1500 Freestyle", 15, 17, 1202930, "Male"),
      _qt("1500 Freestyle", 18, 99, 1167420, "Male"),

      // 50 Backstroke
      _qt("50 Backstroke", 7, 8, 55630, "Male"),
      _qt("50 Backstroke", 9, 9, 49500, "Male"),
      _qt("50 Backstroke", 10, 10, 46870, "Male"),
      _qt("50 Backstroke", 11, 11, 44960, "Male"),
      _qt("50 Backstroke", 12, 12, 42660, "Male"),
      _qt("50 Backstroke", 13, 14, 35870, "Male"),
      _qt("50 Backstroke", 15, 17, 33390, "Male"),
      _qt("50 Backstroke", 18, 99, 32230, "Male"),

      // 100 Backstroke
      _qt("100 Backstroke", 7, 8, 119650, "Male"),
      _qt("100 Backstroke", 9, 9, 106930, "Male"),
      _qt("100 Backstroke", 10, 10, 101740, "Male"),
      _qt("100 Backstroke", 11, 11, 96840, "Male"),
      _qt("100 Backstroke", 12, 12, 91910, "Male"),
      _qt("100 Backstroke", 13, 14, 78020, "Male"),
      _qt("100 Backstroke", 15, 17, 71640, "Male"),
      _qt("100 Backstroke", 18, 99, 69620, "Male"),

      // 200 Backstroke
      _qt("200 Backstroke", 11, 11, 210970, "Male"),
      _qt("200 Backstroke", 12, 12, 200060, "Male"),
      _qt("200 Backstroke", 13, 14, 170620, "Male"),
      _qt("200 Backstroke", 15, 17, 159850, "Male"),
      _qt("200 Backstroke", 18, 99, 155130, "Male"),

      // 50 Breaststroke
      _qt("50 Breaststroke", 7, 8, 61940, "Male"),
      _qt("50 Breaststroke", 9, 9, 55200, "Male"),
      _qt("50 Breaststroke", 10, 10, 51560, "Male"),
      _qt("50 Breaststroke", 11, 11, 48940, "Male"),
      _qt("50 Breaststroke", 12, 12, 45580, "Male"),
      _qt("50 Breaststroke", 13, 14, 38930, "Male"),
      _qt("50 Breaststroke", 15, 17, 36090, "Male"),
      _qt("50 Breaststroke", 18, 99, 34850, "Male"),

      // 100 Breaststroke
      _qt("100 Breaststroke", 7, 8, 136170, "Male"),
      _qt("100 Breaststroke", 9, 9, 121230, "Male"),
      _qt("100 Breaststroke", 10, 10, 113660, "Male"),
      _qt("100 Breaststroke", 11, 11, 108370, "Male"),
      _qt("100 Breaststroke", 12, 12, 100390, "Male"),
      _qt("100 Breaststroke", 13, 14, 85130, "Male"),
      _qt("100 Breaststroke", 15, 17, 79160, "Male"),
      _qt("100 Breaststroke", 18, 99, 76600, "Male"),

      // 200 Breaststroke
      _qt("200 Breaststroke", 11, 11, 231860, "Male"),
      _qt("200 Breaststroke", 12, 12, 214650, "Male"),
      _qt("200 Breaststroke", 13, 14, 184700, "Male"),
      _qt("200 Breaststroke", 15, 17, 173030, "Male"),
      _qt("200 Breaststroke", 18, 99, 167280, "Male"),

      // 50 Butterfly
      _qt("50 Butterfly", 7, 8, 52260, "Male"),
      _qt("50 Butterfly", 9, 9, 46070, "Male"),
      _qt("50 Butterfly", 10, 10, 43570, "Male"),
      _qt("50 Butterfly", 11, 11, 41760, "Male"),
      _qt("50 Butterfly", 12, 12, 39340, "Male"),
      _qt("50 Butterfly", 13, 14, 33090, "Male"),
      _qt("50 Butterfly", 15, 17, 31290, "Male"),
      _qt("50 Butterfly", 18, 99, 29590, "Male"),

      // 100 Butterfly
      _qt("100 Butterfly", 7, 8, 127000, "Male"),
      _qt("100 Butterfly", 9, 9, 105340, "Male"),
      _qt("100 Butterfly", 10, 10, 98610, "Male"),
      _qt("100 Butterfly", 11, 11, 93570, "Male"),
      _qt("100 Butterfly", 12, 12, 87990, "Male"),
      _qt("100 Butterfly", 13, 14, 74310, "Male"),
      _qt("100 Butterfly", 15, 17, 68920, "Male"),
      _qt("100 Butterfly", 18, 99, 65690, "Male"),

      // 200 Butterfly
      _qt("200 Butterfly", 11, 11, 215130, "Male"),
      _qt("200 Butterfly", 12, 12, 198790, "Male"),
      _qt("200 Butterfly", 13, 14, 172260, "Male"),
      _qt("200 Butterfly", 15, 17, 156680, "Male"),
      _qt("200 Butterfly", 18, 99, 152010, "Male"),

      // 200 IM
      _qt("200 IM", 9, 9, 225530, "Male"),
      _qt("200 IM", 10, 10, 213600, "Male"),
      _qt("200 IM", 11, 11, 205040, "Male"),
      _qt("200 IM", 12, 12, 193810, "Male"),
      _qt("200 IM", 13, 14, 167890, "Male"),
      _qt("200 IM", 15, 17, 156640, "Male"),
      _qt("200 IM", 18, 99, 153130, "Male"),

      // 400 IM
      _qt("400 IM", 11, 11, 442780, "Male"),
      _qt("400 IM", 12, 12, 415180, "Male"),
      _qt("400 IM", 13, 14, 364170, "Male"),
      _qt("400 IM", 15, 17, 338500, "Male"),
      _qt("400 IM", 18, 99, 325310, "Male"),
    ];

    for (var qt in times) {
      await _dbHelper.insertQualifyingTime(qt);
    }
  }

  QualifyingTime _qt(String eventRaw, int ageMin, int ageMax, int timeMs, String gender) {
    final parts = eventRaw.split(' ');
    final distance = int.parse(parts[0]);
    final stroke = parts.sublist(1).join(' ');
    
    return QualifyingTime(
      standardName: 'SNAG 2026',
      gender: gender,
      ageMin: ageMin,
      ageMax: ageMax,
      distance: distance,
      stroke: stroke,
      course: 'LCM',
      timeMs: timeMs,
    );
  }
}
