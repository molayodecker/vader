package com.molayo.vendingkiosk;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.*;
import java.util.*;

/** All product, payment, stock and dispense behavior in this activity is simulated. */
public final class GroceryActivity extends Activity {
    static final int GREEN=0xFF123D32, LIME=0xFFB9E769, INK=0xFF1C302A, GREY=0xFF6B8077, BG=0xFFF7FAF8;
    static class Product {
        final String slot,name,category,emoji;
        final int price,tint;
        int stock;
        Product(String slot,String name,String category,String emoji,int price,int stock,int tint){
            this.slot=slot;this.name=name;this.category=category;this.emoji=emoji;this.price=price;this.stock=stock;this.tint=tint;
        }
    }
    final List<Product> products=Arrays.asList(
        new Product("A1","Spring water","Drinks","💧",500,8,0xFFE5F4FF),
        new Product("A2","Orange juice","Drinks","🍊",1200,7,0xFFFFEED9),
        new Product("B1","Greek yogurt","Fresh food","🥛",1600,4,0xFFF0E9FF),
        new Product("B2","Fruit cup","Fresh food","🍓",1800,5,0xFFFFE6E9),
        new Product("C1","Protein bar","Snacks","🍫",1400,6,0xFFF8EFD8),
        new Product("C2","Sparkling water","Drinks","🥤",900,5,0xFFE2F5EB));
    final Map<String,Integer> cart=new LinkedHashMap<>();
    final VendController simulator=new VendController((slot,orderId)->true, orderId->true);
    LinearLayout body,footer;
    String filter="All";

    @Override public void onCreate(Bundle state){
        super.onCreate(state);
        getWindow().setStatusBarColor(GREEN);getWindow().setNavigationBarColor(GREEN);
        LinearLayout root=vertical();root.setBackgroundColor(BG);
        ScrollView scroll=new ScrollView(this);body=vertical();scroll.addView(body);
        root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        footer=vertical();footer.setPadding(d(16),d(10),d(16),d(16));footer.setBackgroundColor(Color.WHITE);
        root.addView(footer);setContentView(root);showCatalog();
    }
    void header(){
        LinearLayout row=horizontal();row.setGravity(Gravity.CENTER_VERTICAL);row.setPadding(d(20),d(15),d(20),d(15));row.setBackgroundColor(GREEN);
        LinearLayout title=vertical();title.addView(text("NOURISH",24,Color.WHITE,true));title.addView(text("SELF-SERVICE MARKET  •  DEMO",10,LIME,true));
        row.addView(title,new LinearLayout.LayoutParams(0,-2,1));row.addView(text("● CHILLED",12,LIME,true));body.addView(row);
    }
    void showCatalog(){
        body.removeAllViews();header();LinearLayout section=section();
        section.addView(text("Fresh picks, anytime.",27,INK,true));section.addView(text("Good food, on your schedule.",14,GREY,false));
        LinearLayout banner=horizontal();banner.setPadding(d(18),d(17),d(18),d(17));banner.setGravity(Gravity.CENTER_VERTICAL);banner.setBackground(shape(GREEN,20));
        LinearLayout promo=vertical();promo.addView(text("FRESH & READY",12,LIME,true));promo.addView(text("A little something delicious.",17,Color.WHITE,true));
        banner.addView(promo,new LinearLayout.LayoutParams(0,-2,1));banner.addView(text("🥬",36,Color.WHITE,false));
        LinearLayout.LayoutParams bp=new LinearLayout.LayoutParams(-1,-2);bp.setMargins(0,d(22),0,d(20));section.addView(banner,bp);
        LinearLayout categories=horizontal();
        for(String category:new String[]{"All","Drinks","Fresh food","Snacks"}){
            TextView chip=text(category,12,category.equals(filter)?Color.WHITE:GREEN,true);chip.setGravity(Gravity.CENTER);
            chip.setPadding(d(5),d(10),d(5),d(10));chip.setBackground(shape(category.equals(filter)?GREEN:Color.WHITE,18));
            LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(0,-2,1);p.rightMargin=d(5);categories.addView(chip,p);
            chip.setOnClickListener(v->{filter=category;showCatalog();});
        }section.addView(categories);
        TextView heading=text("Today's picks",21,INK,true);heading.setPadding(0,d(18),0,d(12));section.addView(heading);
        GridLayout grid=new GridLayout(this);grid.setColumnCount(2);section.addView(grid);
        int i=0;for(Product item:products){
            if(!filter.equals("All")&&!filter.equals(item.category))continue;
            GridLayout.LayoutParams gp=new GridLayout.LayoutParams(GridLayout.spec(i/2),GridLayout.spec(i%2,1f));
            gp.width=0;gp.setGravity(Gravity.FILL_HORIZONTAL);gp.setMargins(0,0,d(i%2==0?7:0),d(12));grid.addView(card(item),gp);i++;
        }updateFooter();
    }
    LinearLayout card(Product item){
        LinearLayout card=vertical();card.setPadding(d(10),d(10),d(10),d(12));card.setBackground(shape(Color.WHITE,18));
        TextView image=text(item.emoji,52,INK,false);image.setGravity(Gravity.CENTER);image.setHeight(d(126));image.setBackground(shape(item.tint,14));card.addView(image);
        card.addView(text(item.name,16,INK,true));card.addView(text("Slot "+item.slot+" · "+item.stock+" left",12,GREY,false));
        card.addView(text(money(item.price),17,GREEN,true));
        Button add=button(item.stock>0?"+ Add":"Sold out",GREEN,Color.WHITE);add.setEnabled(item.stock>0);
        card.addView(add,new LinearLayout.LayoutParams(-1,d(48)));
        add.setOnClickListener(v->{int count=cart.getOrDefault(item.slot,0);if(count<item.stock)cart.put(item.slot,count+1);updateFooter();});
        return card;
    }
    void updateFooter(){
        footer.removeAllViews();int count=0,total=0;
        for(Product p:products){int n=cart.getOrDefault(p.slot,0);count+=n;total+=n*p.price;}
        Button go=button(count==0?"Basket is empty":"View basket · "+count+" items · "+money(total),GREEN,Color.WHITE);
        go.setEnabled(count>0);footer.addView(go,new LinearLayout.LayoutParams(-1,d(58)));go.setOnClickListener(v->showCart());
    }
    void showCart(){
        body.removeAllViews();header();LinearLayout section=section();
        TextView back=text("← Continue shopping",15,GREEN,true);section.addView(back);back.setOnClickListener(v->showCatalog());
        section.addView(text("Your basket",29,INK,true));int total=0;
        for(Product item:products){int count=cart.getOrDefault(item.slot,0);if(count==0)continue;total+=count*item.price;
            LinearLayout line=horizontal();line.setGravity(Gravity.CENTER_VERTICAL);line.setPadding(0,d(13),0,d(13));
            line.addView(text(item.emoji,35,INK,false));LinearLayout details=vertical();details.setPadding(d(10),0,0,0);
            details.addView(text(item.name,16,INK,true));details.addView(text("Slot "+item.slot+" · "+money(item.price),12,GREY,false));
            line.addView(details,new LinearLayout.LayoutParams(0,-2,1));
            Button minus=button("−",0xFFE5EDE7,GREEN);line.addView(minus,new LinearLayout.LayoutParams(d(40),d(47)));
            line.addView(text(" "+count+" ",16,INK,true));Button plus=button("+",0xFFE5EDE7,GREEN);line.addView(plus,new LinearLayout.LayoutParams(d(40),d(47)));
            minus.setOnClickListener(v->change(item,-1));plus.setOnClickListener(v->change(item,1));section.addView(line);
        }
        final int sum=total;section.addView(text("Subtotal  "+money(sum),23,GREEN,true));
        section.addView(text("Demo only · No real money will be collected",12,GREY,false));
        footer.removeAllViews();Button pay=button("Continue to payment →",GREEN,Color.WHITE);pay.setEnabled(sum>0);
        footer.addView(pay,new LinearLayout.LayoutParams(-1,d(58)));pay.setOnClickListener(v->choosePayment(sum));
    }
    void change(Product item,int delta){int next=Math.max(0,Math.min(item.stock,cart.getOrDefault(item.slot,0)+delta));
        if(next==0)cart.remove(item.slot);else cart.put(item.slot,next);showCart();}
    void choosePayment(int sum){new AlertDialog.Builder(this).setTitle("Payment · "+money(sum))
        .setMessage("SIMULATION ONLY: no card, cash or mobile money will be charged.")
        .setItems(new String[]{"Mobile money (demo)","Card (demo)","Cash (demo)"},(dialog,which)->simulate())
        .setNegativeButton("Back",null).show();}
    void simulate(){int quantity=0;
        for(Product item:products){int n=cart.getOrDefault(item.slot,0);
            for(int k=0;k<n;k++){simulator.start(UUID.randomUUID().toString(),item.slot);
                if(simulator.vendIfPaid()!=VendController.Status.COMPLETE){showResult("Demo interrupted",quantity);return;}quantity++;}
            item.stock-=n;
        }cart.clear();showResult("Order complete!",quantity);
    }
    void showResult(String message,int count){body.removeAllViews();footer.removeAllViews();header();
        LinearLayout section=section();section.setGravity(Gravity.CENTER);
        section.addView(text("✨",65,GREEN,false));section.addView(text(message,29,GREEN,true));
        section.addView(text("SIMULATION ONLY — no physical product was dispensed.",14,GREY,false));
        section.addView(text(count+" item(s) simulated",16,INK,true));
        Button again=button("Back to shop",GREEN,Color.WHITE);LinearLayout.LayoutParams p=new LinearLayout.LayoutParams(-1,d(58));p.topMargin=d(30);
        section.addView(again,p);again.setOnClickListener(v->showCatalog());
    }
    LinearLayout section(){LinearLayout panel=vertical();panel.setPadding(d(18),d(18),d(18),d(20));body.addView(panel);return panel;}
    LinearLayout vertical(){LinearLayout v=new LinearLayout(this);v.setOrientation(LinearLayout.VERTICAL);return v;}
    LinearLayout horizontal(){LinearLayout v=new LinearLayout(this);v.setOrientation(LinearLayout.HORIZONTAL);return v;}
    int d(float value){return (int)(value*getResources().getDisplayMetrics().density+.5f);}
    String money(int cents){return String.format(Locale.US,"GH₵ %,.2f",cents/100.0);}
    TextView text(String value,int size,int color,boolean bold){TextView t=new TextView(this);t.setText(value);t.setTextSize(size);t.setTextColor(color);
        if(bold)t.setTypeface(Typeface.DEFAULT,Typeface.BOLD);t.setPadding(0,d(5),0,d(5));return t;}
    GradientDrawable shape(int color,int radius){GradientDrawable g=new GradientDrawable();g.setColor(color);g.setCornerRadius(d(radius));return g;}
    Button button(String label,int bg,int fg){Button b=new Button(this);b.setText(label);b.setAllCaps(false);b.setTextColor(fg);
        b.setTextSize(14);b.setTypeface(Typeface.DEFAULT,Typeface.BOLD);b.setBackground(shape(bg,16));return b;}
}
