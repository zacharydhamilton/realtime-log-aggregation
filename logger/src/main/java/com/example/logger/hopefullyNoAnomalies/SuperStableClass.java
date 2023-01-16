package com.example.logger.hopefullyNoAnomalies;

import java.time.Duration;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.TimeUnit;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.json.JSONObject;
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

@Service
public class SuperStableClass {
    private Logger logger = LogManager.getLogger(SuperStableClass.class);
    private int numErrorsPerMin = 5;

    private Timer anomalyTimer = new Timer("AnomalyTimer");
    private TimerTask anomalyTimerTask = new TimerTask() {
        public void run() {
            int multiplier = 5;
            for (int i=0; i<numErrorsPerMin*multiplier; i++) {
                JSONObject json = new JSONObject();
                json.put("message", "Wow, an error!");
                logger.error(json.toString());
                try {
                    TimeUnit.SECONDS.sleep(60/(numErrorsPerMin*multiplier));
                } catch (InterruptedException ie) {
                    // Do absolutely nothing about it
                }
                
            }
        }
    };

    private Timer baselineTimer = new Timer("BaselineTimer");
    private TimerTask baselineTimerTask = new TimerTask() {
        public void run() {
            for (int i=0; i<numErrorsPerMin; i++) {
                JSONObject json = new JSONObject();
                json.put("message", "Wow, an error!");
                logger.error(json.toString());
                try {
                    TimeUnit.SECONDS.sleep(60/numErrorsPerMin);
                } catch (InterruptedException ie) {
                    // Do absolutely nothing about it
                }
            }
        }
    };
    
    @EventListener(ApplicationStartedEvent.class)
    private void startTimers() {
        baselineTimer.schedule(baselineTimerTask, 0, Duration.ofMinutes(1).toMillis());
        anomalyTimer.schedule(anomalyTimerTask, Duration.ofMinutes(4).toMillis(), Duration.ofMinutes(5).toMillis());
    }
}
