package com.example.logger.relatedErrorsDefNot;

import java.time.Duration;
import java.util.Timer;
import java.util.TimerTask;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.context.event.ApplicationStartedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

@Service
public class Correlator {
    @Autowired
    RelatedClassOne relatedClassOne;

    @Autowired 
    RelatedClassTwo relatedClassTwo;

    private Timer timer = new Timer("Timer");
    private TimerTask timerTask = new TimerTask() {
        public void run() {
            for (int i=0; i<6; i++) {
                String correlationId = UUID.randomUUID().toString();
                relatedClassOne.dependantFunctionOne(correlationId);
                relatedClassTwo.dependantFunctionTwo(correlationId);
                try {
                    TimeUnit.SECONDS.sleep(10);
                } catch (InterruptedException ie) {
                    // Don't worry about it
                }
            }
        }
    };

    @EventListener(ApplicationStartedEvent.class)
    private void startTimer() {
        timer.schedule(timerTask, Duration.ofMinutes(4).toMillis(), Duration.ofMinutes(5).toMillis());
    }
}
