class_name QrGen
extends RefCounted
## QR Code (Model 2, ISO/IEC 18004) kodlayıcı.
## Project Nayuki'nin qrcodegen.py uygulamasının GDScript'e sadık uyarlaması
## (MIT lisansı, Copyright (c) Project Nayuki).
## Tüm sürümler (1–40), 4 hata düzeltme seviyesi, numeric/alphanumeric/byte modları.

enum Ecc { LOW, MEDIUM, QUARTILE, HIGH }

const MIN_VERSION := 1
const MAX_VERSION := 40
const PENALTY_N1 := 3
const PENALTY_N2 := 3
const PENALTY_N3 := 40
const PENALTY_N4 := 10

# Sürüm (1–40) başına hata düzeltme kod sözcüğü sayısı. Sütun 0 dolgu (geçersiz).
const ECC_CODEWORDS_PER_BLOCK := [
	[-1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
	[-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28],
	[-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
	[-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30],
]

# Sürüm başına hata düzeltme blok sayısı.
const NUM_EC_BLOCKS := [
	[-1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25],
	[-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49],
	[-1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68],
	[-1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81],
]

const MODE_BITS := {"numeric": 0x1, "alphanumeric": 0x2, "byte": 0x4}
const MODE_CCBITS := {"numeric": [10, 12, 14], "alphanumeric": [9, 11, 13], "byte": [8, 16, 16]}
const ALPHANUMERIC_CHARS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:"

# Sonuç alanları (encode_* çağrısından sonra doldurulur)
var version := 0
var size := 0
var ecl: int = Ecc.MEDIUM
var mask := 0
var modules := PackedByteArray()   # size*size, 1 = koyu
var valid := false

var _isfunc := PackedByteArray()


# --- Genel API -------------------------------------------------------------

static func ecc_from_name(n: String) -> int:
	match n.strip_edges().to_upper():
		"L":
			return Ecc.LOW
		"Q":
			return Ecc.QUARTILE
		"H":
			return Ecc.HIGH
		_:
			return Ecc.MEDIUM


## Metni QR koduna çevirir. Çok uzunsa false döner (valid == false).
func encode_text(text: String, ecl_level: int) -> bool:
	var segs := _make_segments(text)
	return _encode_segments(segs, ecl_level, true)


func encode_bytes(data: PackedByteArray, ecl_level: int) -> bool:
	var bits: Array = []
	for b in data:
		_append_bits(bits, int(b), 8)
	return _encode_segments([{"mode": "byte", "numchars": data.size(), "bits": bits}], ecl_level, true)


## Oluşturulan matrisi Image olarak döndürür (sessiz alan + ölçek).
func to_image(scale := 8, quiet := 4, fg := Color.BLACK, bg := Color.WHITE) -> Image:
	if not valid:
		return null
	var dim := (size + quiet * 2) * scale
	var img := Image.create(dim, dim, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	for y in size:
		for x in size:
			if modules[y * size + x] == 1:
				var px := (x + quiet) * scale
				var py := (y + quiet) * scale
				img.fill_rect(Rect2i(px, py, scale, scale), fg)
	return img


func to_texture(scale := 8, quiet := 4, fg := Color.BLACK, bg := Color.WHITE) -> ImageTexture:
	var img := to_image(scale, quiet, fg, bg)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)


# --- Segment üretimi -------------------------------------------------------

func _is_numeric(text: String) -> bool:
	if text.is_empty():
		return true
	for i in text.length():
		var c := text.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return true


func _is_alphanumeric(text: String) -> bool:
	for i in text.length():
		if not ALPHANUMERIC_CHARS.contains(text[i]):
			return false
	return true


func _make_segments(text: String) -> Array:
	if text.is_empty():
		return []
	if _is_numeric(text):
		var bits: Array = []
		var i := 0
		while i < text.length():
			var n: int = mini(3, text.length() - i)
			_append_bits(bits, int(text.substr(i, n)), n * 3 + 1)
			i += n
		return [{"mode": "numeric", "numchars": text.length(), "bits": bits}]
	if _is_alphanumeric(text):
		var bits2: Array = []
		var idx := 0
		while idx + 1 < text.length():
			var temp := ALPHANUMERIC_CHARS.find(text[idx]) * 45
			temp += ALPHANUMERIC_CHARS.find(text[idx + 1])
			_append_bits(bits2, temp, 11)
			idx += 2
		if text.length() % 2 == 1:
			_append_bits(bits2, ALPHANUMERIC_CHARS.find(text[text.length() - 1]), 6)
		return [{"mode": "alphanumeric", "numchars": text.length(), "bits": bits2}]
	# byte modu: UTF-8
	var utf8 := text.to_utf8_buffer()
	var bits3: Array = []
	for b in utf8:
		_append_bits(bits3, int(b), 8)
	return [{"mode": "byte", "numchars": utf8.size(), "bits": bits3}]


# --- Çekirdek kodlayıcı ----------------------------------------------------

func _encode_segments(segs: Array, ecl0: int, boost: bool, min_version := 1, max_version := 40, forced_mask := -1) -> bool:
	valid = false
	if min_version < MIN_VERSION or max_version > MAX_VERSION or max_version < min_version or forced_mask < -1 or forced_mask > 7:
		return false

	# Uygun en küçük sürümü bul
	var version_found := -1
	var data_used := -1
	for v in range(min_version, max_version + 1):
		var cap_bits := _num_data_codewords(v, ecl0) * 8
		var used := _total_bits(segs, v)
		if used >= 0 and used <= cap_bits:
			version_found = v
			data_used = used
			break
	if version_found < 0:
		return false  # veri çok uzun

	var ecl := ecl0
	# Hata düzeltme seviyesini, kapasite izin veriyorsa yükselt
	if boost:
		for newecl in [Ecc.MEDIUM, Ecc.QUARTILE, Ecc.HIGH]:
			if data_used <= _num_data_codewords(version_found, newecl) * 8:
				ecl = newecl

	# Bit akışını kur
	var bb: Array = []
	for seg in segs:
		var mode: String = seg["mode"]
		var ccbits: Array = MODE_CCBITS[mode]
		_append_bits(bb, MODE_BITS[mode], 4)
		_append_bits(bb, int(seg["numchars"]), int(ccbits[(version_found + 7) / 17]))
		for bit in seg["bits"]:
			bb.append(bit)
	if bb.size() != data_used:
		return false

	var cap_bits := _num_data_codewords(version_found, ecl) * 8
	# Sonlandırıcı + bayta hizala + dolgu
	_append_bits(bb, 0, mini(4, cap_bits - bb.size()))
	var pad_bits := (8 - bb.size() % 8) % 8
	_append_bits(bb, 0, pad_bits)
	var pad_toggle := 0
	while bb.size() < cap_bits:
		_append_bits(bb, 0xEC if pad_toggle == 0 else 0x11, 8)
		pad_toggle = 1 - pad_toggle

	# Bitleri sözcüklere paketle
	var data_codewords := PackedByteArray()
	data_codewords.resize(bb.size() / 8)
	for i in bb.size():
		if bb[i] == 1:
			data_codewords[i >> 3] = data_codewords[i >> 3] | (1 << (7 - (i & 7)))

	return _build(version_found, ecl, data_codewords, forced_mask)


# --- Inşa (constructor karşılığı) -----------------------------------------

func _build(ver: int, ecl_level: int, data_codewords: PackedByteArray, msk: int) -> bool:
	version = ver
	size = ver * 4 + 17
	ecl = ecl_level
	modules = PackedByteArray()
	modules.resize(size * size)
	_isfunc = PackedByteArray()
	_isfunc.resize(size * size)

	_draw_function_patterns()
	var all_codewords := _add_ecc_and_interleave(data_codewords)
	_draw_codewords(all_codewords)

	if msk == -1:
		var min_penalty := 1 << 40
		var best := 0
		for i in 8:
			_apply_mask(i)
			_draw_format_bits(i)
			var penalty := _get_penalty_score()
			if penalty < min_penalty:
				min_penalty = penalty
				best = i
			_apply_mask(i)  # geri al
		msk = best
	mask = msk
	_apply_mask(msk)
	_draw_format_bits(msk)
	valid = true
	return true


func _set_func(x: int, y: int, dark: bool) -> void:
	if x < 0 or y < 0 or x >= size or y >= size:
		return
	modules[y * size + x] = 1 if dark else 0
	_isfunc[y * size + x] = 1


func _draw_function_patterns() -> void:
	for i in size:
		_set_func(6, i, i % 2 == 0)
		_set_func(i, 6, i % 2 == 0)
	_draw_finder_pattern(3, 3)
	_draw_finder_pattern(size - 4, 3)
	_draw_finder_pattern(3, size - 4)
	var positions := _alignment_positions()
	var n := positions.size()
	for i in n:
		for j in n:
			if (i == 0 and j == 0) or (i == 0 and j == n - 1) or (i == n - 1 and j == 0):
				continue
			_draw_alignment_pattern(positions[i], positions[j])
	_draw_format_bits(0)
	_draw_version_bits()


func _draw_finder_pattern(x: int, y: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var xx := x + dx
			var yy := y + dy
			if xx >= 0 and yy >= 0 and xx < size and yy < size:
				var dist := maxi(abs(dx), abs(dy))
				_set_func(xx, yy, dist != 2 and dist != 4)


func _draw_alignment_pattern(x: int, y: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_func(x + dx, y + dy, maxi(abs(dx), abs(dy)) != 1)


func _format_data_bits(m: int) -> int:
	var fmtbits: int = [1, 0, 3, 2][ecl]  # Low=1, Med=0, Quart=3, High=2
	var data: int = (fmtbits << 3) | m
	var rem: int = data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	return ((data << 10) | rem) ^ 0x5412


func _draw_format_bits(m: int) -> void:
	var bits := _format_data_bits(m)
	for i in range(0, 6):
		_set_func(8, i, _get_bit(bits, i))
	_set_func(8, 7, _get_bit(bits, 6))
	_set_func(8, 8, _get_bit(bits, 7))
	_set_func(7, 8, _get_bit(bits, 8))
	for i in range(9, 15):
		_set_func(14 - i, 8, _get_bit(bits, i))
	for i in range(0, 8):
		_set_func(size - 1 - i, 8, _get_bit(bits, i))
	for i in range(8, 15):
		_set_func(8, size - 15 + i, _get_bit(bits, i))
	_set_func(8, size - 8, true)  # her zaman koyu


func _draw_version_bits() -> void:
	if version < 7:
		return
	var rem := version
	for i in 12:
		rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
	var bits := (version << 12) | rem
	for i in 18:
		var bit := _get_bit(bits, i)
		var a := size - 11 + i % 3
		var b := i / 3
		_set_func(a, b, bit)
		_set_func(b, a, bit)


func _alignment_positions() -> Array:
	if version == 1:
		return []
	var numalign := version / 7 + 2
	var step: int = int((version * 8 + numalign * 3 + 5) / (numalign * 4 - 4)) * 2
	var result: Array = []
	for i in range(numalign - 1):
		result.append(size - 7 - i * step)
	result.append(6)
	result.reverse()
	return result


# --- ECC + interleaving -----------------------------------------------------

func _add_ecc_and_interleave(data: PackedByteArray) -> PackedByteArray:
	var ver := version
	var numblocks: int = NUM_EC_BLOCKS[ecl][ver]
	var blockecclen: int = ECC_CODEWORDS_PER_BLOCK[ecl][ver]
	var rawcodewords := _num_raw_data_modules(ver) / 8
	var numshortblocks := numblocks - rawcodewords % numblocks
	var shortblocklen := rawcodewords / numblocks

	var rsdiv := _rs_divisor(blockecclen)
	var blocks: Array = []
	var k := 0
	for i in numblocks:
		var dat_len := shortblocklen - blockecclen + (0 if i < numshortblocks else 1)
		var dat := PackedByteArray()
		dat.resize(dat_len)
		for j in dat_len:
			dat[j] = data[k + j]
		k += dat_len
		var ecc := _rs_remainder(dat, rsdiv)
		if i < numshortblocks:
			dat.append(0)
		for b in ecc:
			dat.append(b)
		blocks.append(dat)

	var result := PackedByteArray()
	var blocklen: int = (blocks[0] as PackedByteArray).size()
	for i in blocklen:
		for j in numblocks:
			if i != shortblocklen - blockecclen or j >= numshortblocks:
				result.append((blocks[j] as PackedByteArray)[i])
	return result


func _rs_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree - 1)
	for i in degree - 1:
		result[i] = 0
	result.append(1)
	var root := 1
	for i in degree:
		for j in degree:
			result[j] = _rs_multiply(result[j], root)
			if j + 1 < degree:
				result[j] = result[j] ^ result[j + 1]
		root = _rs_multiply(root, 2)
	return result


func _rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for i in divisor.size():
		result[i] = 0
	for b in data:
		var factor := b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in divisor.size():
			result[i] = result[i] ^ _rs_multiply(divisor[i], factor)
	return result


func _rs_multiply(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z


# --- Çizim: sözcükler -------------------------------------------------------

func _draw_codewords(data: PackedByteArray) -> void:
	var i := 0
	var total_bits := data.size() * 8
	var right := size - 1
	while right >= 1:
		var r := right
		if r <= 6:
			r -= 1
		for vert in size:
			for j in 2:
				var x := r - j
				var upward: bool = ((r + 1) & 2) == 0
				var y := (size - 1 - vert) if upward else vert
				if _isfunc[y * size + x] == 0 and i < total_bits:
					var bit := (data[i >> 3] >> (7 - (i & 7))) & 1
					modules[y * size + x] = bit
					i += 1
		right -= 2


func _mask_at(m: int, x: int, y: int) -> bool:
	match m:
		0:
			return (x + y) % 2 == 0
		1:
			return y % 2 == 0
		2:
			return x % 3 == 0
		3:
			return (x + y) % 3 == 0
		4:
			return (x / 3 + y / 2) % 2 == 0
		5:
			return x * y % 2 + x * y % 3 == 0
		6:
			return (x * y % 2 + x * y % 3) % 2 == 0
		7:
			return ((x + y) % 2 + x * y % 3) % 2 == 0
	return false


func _apply_mask(m: int) -> void:
	for y in size:
		for x in size:
			if _isfunc[y * size + x] == 0:
				if _mask_at(m, x, y):
					modules[y * size + x] ^= 1


# --- Cezalama puanı ---------------------------------------------------------

func _get_penalty_score() -> int:
	var result := 0
	# Satırlar
	for y in size:
		var runcolor := false
		var runlen := 0
		var rh := [0, 0, 0, 0, 0, 0, 0]
		for x in size:
			var dark := modules[y * size + x] == 1
			if dark == runcolor:
				runlen += 1
				if runlen == 5:
					result += PENALTY_N1
				elif runlen > 5:
					result += 1
			else:
				_add_history(runlen, rh)
				if not runcolor:
					result += _count_patterns(rh) * PENALTY_N3
				runcolor = dark
				runlen = 1
		result += _terminate_and_count(runcolor, runlen, rh) * PENALTY_N3
	# Sütunlar
	for x in size:
		var runcolor2 := false
		var runlen2 := 0
		var rh2 := [0, 0, 0, 0, 0, 0, 0]
		for y in size:
			var dark := modules[y * size + x] == 1
			if dark == runcolor2:
				runlen2 += 1
				if runlen2 == 5:
					result += PENALTY_N1
				elif runlen2 > 5:
					result += 1
			else:
				_add_history(runlen2, rh2)
				if not runcolor2:
					result += _count_patterns(rh2) * PENALTY_N3
				runcolor2 = dark
				runlen2 = 1
		result += _terminate_and_count(runcolor2, runlen2, rh2) * PENALTY_N3
	# 2x2 bloklar
	for y in range(size - 1):
		for x in range(size - 1):
			var v := modules[y * size + x]
			if v == modules[y * size + x + 1] and v == modules[(y + 1) * size + x] and v == modules[(y + 1) * size + x + 1]:
				result += PENALTY_N2
	# Denge
	var dark_total := 0
	for v in modules:
		dark_total += v
	var total := size * size
	var k: int = (absi(dark_total * 20 - total * 10) + total - 1) / total - 1
	result += clampi(k, 0, 9) * PENALTY_N4
	return result


func _add_history(runlength: int, rh: Array) -> void:
	var rl := runlength
	if rh[0] == 0:
		rl += size  # ilk koşuya açık sınır payı
	rh.pop_back()
	rh.push_front(rl)


func _count_patterns(rh: Array) -> int:
	var n: int = rh[1]
	var core: bool = n > 0 and rh[2] == n and rh[4] == n and rh[5] == n and rh[3] == n * 3
	var a := 1 if (core and rh[0] >= n * 4 and rh[6] >= n) else 0
	var b := 1 if (core and rh[6] >= n * 4 and rh[0] >= n) else 0
	return a + b


func _terminate_and_count(runcolor: bool, runlength: int, rh: Array) -> int:
	var rl := runlength
	if runcolor:
		_add_history(rl, rh)
		rl = 0
	rl += size
	_add_history(rl, rh)
	return _count_patterns(rh)


# --- Sayılar ----------------------------------------------------------------

func _num_raw_data_modules(ver: int) -> int:
	var result := (16 * ver + 128) * ver + 64
	if ver >= 2:
		var numalign := ver / 7 + 2
		result -= (25 * numalign - 10) * numalign - 55
	if ver >= 7:
		result -= 36
	return result


func _num_data_codewords(ver: int, ecl_level: int) -> int:
	return _num_raw_data_modules(ver) / 8 - ECC_CODEWORDS_PER_BLOCK[ecl_level][ver] * NUM_EC_BLOCKS[ecl_level][ver]


func _total_bits(segs: Array, ver: int) -> int:
	var result := 0
	for seg in segs:
		var mode: String = seg["mode"]
		var ccbits: Array = MODE_CCBITS[mode]
		var cc: int = int(ccbits[(ver + 7) / 17])
		if int(seg["numchars"]) >= (1 << cc):
			return -1
		result += 4 + cc + (seg["bits"] as Array).size()
	return result


static func _append_bits(buf: Array, val: int, n: int) -> void:
	for i in range(n - 1, -1, -1):
		buf.append((val >> i) & 1)


static func _get_bit(x: int, i: int) -> bool:
	return ((x >> i) & 1) != 0
