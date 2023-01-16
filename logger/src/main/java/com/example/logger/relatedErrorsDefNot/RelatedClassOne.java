package com.example.logger.relatedErrorsDefNot;

import org.apache.logging.log4j.Logger;
import org.json.JSONObject;

import java.time.Duration;
import java.util.Timer;
import java.util.TimerTask;
import java.util.UUID;

import org.apache.logging.log4j.LogManager;
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

@Service
public class RelatedClassOne {
    private Logger logger = LogManager.getLogger(RelatedClassOne.class);
    
    private Timer baselineTimer = new Timer("BaselineTimer");
    private TimerTask baselineTimerTask = new TimerTask() {
        public void run() {
            JSONObject json = new JSONObject(); 
            json.put("message", "Wow, information, cool!");
            json.put("correlationId", UUID.randomUUID().toString());
            logger.info(json.toString());
        }
    };

    public void dependantFunctionOne(String correlationId) {
        JSONObject json = new JSONObject();
        json.put("message", "Uh oh, something broke!");
        json.put("correlationId", correlationId);
        logger.error(json.toString());
    }

    @EventListener(ApplicationStartedEvent.class)
    private void startTimer() {
        baselineTimer.schedule(baselineTimerTask, 0, Duration.ofSeconds(1).toMillis());
    }
}
