package nexvyn;

/**
 * A function the system calls later: timers, network results, dialogs. Write it as a lambda:
 * {@code Timer.after(1.5, args -> hideToast());} or {@code Net.json(url, args -> show((Record) args[0], args[1]));}
 * The arguments are the ones the SDK documents for the call (numbers are Double, maps are Record, null = none).
 */
public interface Callback {
    void call(Object... args);
}
