def step(minute, second, tick, enable):
    if not enable or not tick:
        return minute, second
    if second < 59:
        return minute, second + 1
    if minute < 59:
        return minute + 1, 0
    return 0, 0

def run():
    m = s = 0
    seen = set()

    for _ in range(3600):
        seen.add((m, s))
        m, s = step(m, s, True, True)

    assert len(seen) == 3600
    assert (m, s) == (0, 0)

    assert step(0, 58, True, True) == (0, 59)
    assert step(0, 59, True, True) == (1, 0)
    assert step(59, 59, True, True) == (0, 0)
    assert step(12, 34, False, True) == (12, 34)
    assert step(12, 34, True, False) == (12, 34)

    print("D07 reference model PASS")
    print("3600 unique minute:second states verified.")

if __name__ == "__main__":
    run()
