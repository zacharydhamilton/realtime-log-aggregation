package com.example.logger.requiringDecoration;

import java.util.HashMap;

import org.springframework.stereotype.Component;

@Component
public class Decorations {
    public HashMap<String, String> teams = new HashMap<String, String>() {{
        put("1234", "FrontEnd");
        put("5678", "BackEnd");
    }};
    public HashMap<String, String> warns = new HashMap<String, String>() {{
        put("9476", "SlowerThanNormal");
        put("6780", "ExtraConfigProvided");
        put("3058", "DeprecationFlag");
        put("9853", "MissingParams");
    }};
    public HashMap<String, String> errors = new HashMap<String, String>() {{
        put("5643", "BrokenTree");
        put("1325", "StackUnderflow");
        put("9797", "OutOfEnergy");
        put("4836", "TooMuchStorage");
        put("2958", "RunawayProcess");
        put("2067", "TooManyRequests");
        put("0983", "SleptTooLong");
    }};
    public HashMap<String, String> contacts = new HashMap<String, String>() {{
        put("u6496", "Eric MacKay");
        put("u5643", "Zachary Hamilton");
        put("u6739", "Steve Jobs");
        put("u3650", "Bill Gates");
    }};
}
