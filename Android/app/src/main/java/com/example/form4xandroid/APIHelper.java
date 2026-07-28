package com.example.form4xandroid;

import android.os.AsyncTask;

import java.io.BufferedReader;
import java.io.DataOutputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;

public class APIHelper extends AsyncTask<String, Void, String> {

    String url;
    String method;
    HttpURLConnection connection;

    public APIHelper(String url, String method) {
        this.url = url;
        this.method = method;

        try {
            this.connection=(HttpURLConnection) new URL(url).openConnection();
            this.connection.setRequestMethod(method);
            this.connection.setRequestProperty("Content-Type", "application/json");
        } catch (IOException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    protected String doInBackground(String... strings) {

        if (strings.length>0)
        {
            try {
                     DataOutputStream sender = new DataOutputStream(connection.getOutputStream());
                     sender.writeBytes(strings[0]);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }
        BufferedReader readerr;
        try {
            readerr= new BufferedReader(new InputStreamReader(connection.getInputStream()));
        } catch (IOException e) {
            readerr = new BufferedReader(new InputStreamReader(connection.getErrorStream()));
        }

        String result = "";

        while (true)
        {
            String readed = null;

            try {
                readed = readerr.readLine();
            } catch (IOException e) {
                throw new RuntimeException(e);
            }

            if (readed == null)
            {
                break;
            }

            result += readed;
        }

        return result;
    }
}
