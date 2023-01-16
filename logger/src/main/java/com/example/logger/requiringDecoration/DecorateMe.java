package com.example.logger.requiringDecoration;

import java.time.Duration;
import java.util.Random;
import java.util.Timer;
import java.util.TimerTask;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

@Service
public class DecorateMe {
    private Logger logger = LogManager.getLogger(DecorateMe.class);
    
    @Autowired
    Decorations decorations;

    private Timer infoLevelTimer = new Timer("InfoLevelTimer");
    private TimerTask infoLevelTimerTask = new TimerTask() {
        public void run() {
            Random random = new Random();
            JSONObject json = new JSONObject();
            json.put("message", "Something happened");
            Object[] teamIds = decorations.teams.keySet().toArray();
            json.put("team", teamIds[random.nextInt(teamIds.length)]);
            Object[] contacts = decorations.contacts.keySet().toArray();
            json.put("contact", contacts[random.nextInt(contacts.length)]);
            json.put("code", "0000");
            logger.info(json.toString());
        }
    };

    private Timer warnLevelTimer = new Timer("WarnLevelTimer");
    private TimerTask warnLevelTimerTask = new TimerTask() {
        public void run() {
            Random random = new Random();
            JSONObject json = new JSONObject();
            json.put("message", "Something not great happened");
            Object[] teamIds = decorations.teams.keySet().toArray();
            json.put("team", teamIds[random.nextInt(teamIds.length)]);
            Object[] contacts = decorations.contacts.keySet().toArray();
            json.put("contact", contacts[random.nextInt(contacts.length)]);
            Object[] warnCodes = decorations.warns.keySet().toArray();
            json.put("code", warnCodes[random.nextInt(warnCodes.length)]); 
            logger.warn(json.toString());
        }
    };

    private Timer errorLevelTimer = new Timer("ErrorLevelTimer");
    private TimerTask errorLevelTimerTask = new TimerTask() {
        public void run() {
            Random random = new Random();
            JSONObject json = new JSONObject();
            json.put("message", "Something bad happened");
            Object[] teamIds = decorations.teams.keySet().toArray();
            json.put("team", teamIds[random.nextInt(teamIds.length)]);
            Object[] contacts = decorations.contacts.keySet().toArray();
            json.put("contact", contacts[random.nextInt(contacts.length)]);
            Object[] errorCodes = decorations.errors.keySet().toArray();
            json.put("code", errorCodes[random.nextInt(errorCodes.length)]); 
            logger.error(json.toString());
        }
    };

    @EventListener(ApplicationStartedEvent.class)
    private void startTimer() {
        infoLevelTimer.schedule(infoLevelTimerTask, Duration.ofSeconds(0).toMillis(), Duration.ofSeconds(10).toMillis());
        warnLevelTimer.schedule(warnLevelTimerTask, Duration.ofSeconds(3).toMillis(), Duration.ofSeconds(10).toMillis());
        errorLevelTimer.schedule(errorLevelTimerTask, Duration.ofSeconds(6).toMillis(), Duration.ofSeconds(10).toMillis());
    }
}
