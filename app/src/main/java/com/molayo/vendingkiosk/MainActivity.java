package com.molayo.vendingkiosk;

import android.app.Activity;
import android.os.Bundle;
import android.graphics.Color;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import java.util.UUID;

public final class MainActivity extends Activity {
    private TextView feedback;
    private final VendController controller = new VendController(
        (slot, orderId) -> true, // Simulated dispenser, never touches hardware.
        orderId -> true           // Simulated payment verification, never transfers funds.
    );

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_FULLSCREEN);
        ScrollView scroll = new ScrollView(this);
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(32, 48, 32, 40);
        root.setBackgroundColor(Color.rgb(247, 250, 248));
        scroll.addView(root);
        label(root, "VEND / DEMO", 17, Color.rgb(30, 121, 90));
        label(root, "Fresh picks, anytime.", 29, Color.rgb(20, 48, 43));
        label(root, "Hardware disconnected  •  Simulated payment", 14, Color.DKGRAY);
        label(root, "Choose a sample item", 21, Color.rgb(20, 48, 43));
        addProduct(root, "A1", "Chilled water", "GH₵ 5.00");
        addProduct(root, "B2", "Fruit juice", "GH₵ 12.00");
        addProduct(root, "C3", "Fresh snack", "GH₵ 15.00");
        feedback = label(root, "Ready for a simulated purchase.", 16, Color.rgb(30, 121, 90));
        setContentView(scroll);
    }

    private void addProduct(LinearLayout root, String slot, String name, String price) {
        Button button = new Button(this);
        button.setText(slot + "  •  " + name + "  •  " + price + "\nSIMULATE PURCHASE");
        button.setAllCaps(false);
        button.setGravity(Gravity.CENTER_VERTICAL);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, 140);
        params.topMargin = 18;
        root.addView(button, params);
        button.setOnClickListener(v -> {
            try {
                controller.start(UUID.randomUUID().toString(), slot);
                VendController.Status result = controller.vendIfPaid();
                feedback.setText(result == VendController.Status.COMPLETE
                    ? "SIMULATED SUCCESS: " + slot + " — no physical product dispensed."
                    : "SIMULATED STATUS: " + result);
            } catch (Exception ex) {
                feedback.setText("Demo error: " + ex.getMessage());
            }
        });
    }

    private TextView label(LinearLayout root, String text, int sp, int color) {
        TextView view = new TextView(this);
        view.setText(text);
        view.setTextSize(sp);
        view.setTextColor(color);
        view.setPadding(0, 10, 0, 10);
        root.addView(view);
        return view;
    }
}
